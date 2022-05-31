% principle: use a threshold/baseline for peak detection
% short pulses have lower peaks
% long pulses have high peaks

% TODO: take into account delta in recovery times
% TODO: implement some basic calibration

main()

function main()
    %a = arduino();

    % receiver params
    high_thresh = 2.75;
    low_thresh = 2;
    lag = 1;
    samplingRate = 0.05; % max is 0.05
    dsdt_thresh = 2.1;
    dsdt_baseline = 0.1;
    n = 12;
    %holdTime = 2;

    % init arrays
    s = [];
    t = [];

    % value thresholding params
    vthresh_bits = [];
    % mode 0 - listening
    % mode 1 - locked on, detecting peak
    % mode 2 - peak detected, waiting for fall
    vthresh_mode = 0;
    vthresh_timer = 0;

    % derivative thresholding params
    dthresh_bits = [];
    dthresh_mode = 0;
    dthresh_start = 0;
    dthresh_end = 0;

    % 20 Hz is the best we can do given the Arduino-MATLAB bottleneck
    %r = rateControl(1/samplingRate);
    r = robotics.Rate(1/samplingRate);

    holdTrackT = 0;

    % internal for drawing
    triggerValue = 0;
    desc = ["listening for new data", "tracking a peak", "waiting for recovery, ignoring data"];
    cols = ['g', 'b', 'r'];

    % only stop after n + 1 bits received
    bits_rx = 0;
    tic
    while bits_rx <= (n + 1)
        % grab new data
        now = readVoltage(a, 'A0');
        s = [s, now];
        t = [t, toc];

        % calculate a moving mean for noise reduction
        s_avg = movmean(s, 7);
        dsdt = gradient(s_avg, samplingRate);

        plot(t, s, 'Color', 'k');
        hold on;
        plot(t, s_avg, 'Color', 'r');
        hold off;
        hold on;
        plot(t, dsdt, 'Color', 'b');
        hold off;
        yline(high_thresh);
        yline(low_thresh);  
        axis([0 inf 0 4]);
        title(gca, sprintf('mode %i - %s', vthresh_mode, desc(vthresh_mode + 1)), 'Color', cols(vthresh_mode + 1));

        % value thresholding
        if vthresh_mode == 0
            if s_avg(end) > low_thresh
                %fprintf('locked on, tracking signal rise\n')
                vthresh_timer = toc;
                vthresh_mode = 1;
                triggerValue = t(end);
            end
        elseif vthresh_mode == 1
            % wait some time before deciding high or low
            xline(triggerValue, 'Color', 'b');
            xline(triggerValue + lag, 'Color', 'r');
            if toc - vthresh_timer > lag
                if s_avg(end) > high_thresh
                    %fprintf('continual rise detected, likely high\n')
                    vthresh_bits = [vthresh_bits, 1];
                else
                    %fprintf('continual rise not detected, likely low\n')
                    vthresh_bits = [vthresh_bits, 0];
                end
                vthresh_mode = 2;
                %holdTrackT = toc;
                %fprintf('holding: ignoring all rises')
            end
        elseif vthresh_mode == 2
            if s_avg(end) < low_thresh
                %< low_thresh && (toc - holdTrackT) > holdTime
                vthresh_mode = 0;
                fprintf("vthresh decision: got %i -- count %i\n", vthresh_bits(end), bits_rx);
            end
        end

        % derivative thresholding
        yline(dsdt_thresh, 'Color', 'r');
        if dthresh_mode == 0
            if dsdt(end) > dsdt_baseline
                dthresh_mode = 1;
                dthresh_start = size(dsdt, 2);
            end
        elseif dthresh_mode == 1
            % derivative peaks fall very quickly to noise
            if dsdt(end) < dsdt_baseline
                dthresh_mode = 2;
                dthresh_end = size(dsdt, 2);
            end
        elseif dthresh_mode == 2
            subset = dsdt(dthresh_start:dthresh_end);
            peak = max(subset);
            if peak > dsdt_thresh
                dthresh_bits = [dthresh_bits, 1];
            else
                dthresh_bits = [dthresh_bits, 0];
            end
            dthresh_mode = 0;
            fprintf("dthresh decision: got %i -- count %i\n", dthresh_bits(end), bits_rx);
        end


        drawnow
        % fixed sampling period

        % make a decision on received bits once both algorithms complete
        dFoundBit = size(dthresh_bits, 2) == bits_rx + 1;
        vFoundBit = size(vthresh_bits, 2) == bits_rx + 1;
        if dFoundBit && vFoundBit
            disp(dthresh_bits)
            disp(vthresh_bits)
            bits_rx = bits_rx + 1;
        end
        
        waitfor(r);
    end
end
