% principle: use a threshold/baseline for peak detection
% short pulses have lower peaks
% long pulses have high peaks

% TODO: take into account delta in recovery times
% TODO: implement some basic calibration

main()

function y = f(x)
    y = sin(x).*sin(x) + sin(x + 0.3)*0.5 + 0.5;
end

function main()
    %a = arduino();

    % receiver params
    high_thresh = 1.5;
    low_thresh = 0.8;
    lag = 1;
    tolerance = 0.9;

    % init arrays
    s = [];
    t = [];
    bits = [];

    input = f(linspace(0, 150, 2000));
    i = 1;

    % 20 Hz is the best we can do given the Arduino-MATLAB bottleneck
    r = rateControl(20);
    % mode 0 - listening
    % mode 1 - locked on, detecting peak
    % mode 2 - peak detected, waiting for fall
    mode = 0;
    startedTrackingT = 0;

    % internal for drawing
    triggerValue = 0;

    % only stop after 20 bits received
    tic
    while size(bits) < 10
        % grab new data
        %now = readVoltage(a, 'A0');
        now = input(i);
        i = i + 1;
        s = [s, now];
        t = [t, toc];

        % calculate a moving mean for noise reduction
        s_avg = movmean(s, 5);

        %plot(t, s, 'Color', 'k');
        %hold on;
        plot(t, s_avg, 'Color', 'r');
        %hold off;
        yline(high_thresh);
        yline(low_thresh);  
        axis([0 inf 0 2.5]);

        if mode == 0
            if s_avg(end) > low_thresh
                fprintf('locked on, tracking signal rise\n')
                startedTrackingT = toc;
                mode = 1;
                triggerValue = t(end);
            end
        elseif mode == 1
            % wait some time before deciding high or low
            xline(triggerValue, 'Color', 'b');
            xline(triggerValue + lag, 'Color', 'r');
            if toc - startedTrackingT > lag
                if s_avg(end) > high_thresh
                    fprintf('continual rise detected, likely high\n')
                    bits = [bits, 1];
                else
                    %fprintf('continual rise not detected, likely low\n')
                    bits = [bits, 0];
                end
                mode = 2;
            end
        elseif mode == 2
            if s_avg(end) < low_thresh
                mode = 0;
            end
        end

        drawnow
        % fixed sampling period
        waitfor(r);
    end
    disp(bits)
end 

function t = createLagTimer(delta)
    t = timer;
    t.TimerFcn = @tfcn;
    t.StartDelay = delta;
    t.UserData = true;

    function tfcn(mTimer,~)
        %disp('finished measuring noise')
        t.UserData = false;
    end
end
