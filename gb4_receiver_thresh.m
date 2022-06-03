% principle: use a threshold/baseline for peak detection
% short pulses have lower peaks
% long pulses have high peaks

% TODO: take into account delta in recovery times
% TODO: implement some basic calibration

main()

function main()
    a = arduino();
    
    % receiver-drone interface params
    epw = 0.1;
    pT = timer("StartDelay", epw); %set the switching pulse width
    pT.TimerFcn = @(~,~)fprintf('');
    inAir = false;

    % receiver params
    high_thresh = 2.75;
    low_thresh = 2;
    lag = 0.6;
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
    dthresh_hold = 5;
    dthresh_holdT = 0;

    % bit decision params
    bitSyncWait = 6;
    bitSyncWaitT = 0;
    needsBitSync = false;

    % 20 Hz is the best we can do given the Arduino-MATLAB bottleneck
    %r = rateControl(1/samplingRate);
    r = robotics.Rate(1/samplingRate);

    % internal for drawing
    triggerValue = 0;
    desc = ["listening for new data", "tracking a peak", "waiting for recovery, ignoring data"];
    cols = ['g', 'b', 'r'];

    
    % only stop after n + 1 bits received
    tic
    while size(dthresh_bits, 2) <= (n + 1)
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
                %fprintf('holding: ignoring all rises')
            end
        elseif vthresh_mode == 2
            if s_avg(end) < low_thresh
                %< low_thresh && (toc - holdTrackT) > holdTime
                vthresh_mode = 0;
                printArray(vthresh_bits, "value thresholding");
            end
        end

        % derivative thresholding
        yline(dsdt_thresh, 'Color', 'r');
        if dthresh_mode == 0
            if dsdt(end) > dsdt_baseline
                % bit syncing
                bitSyncWaitT = toc; % derivative always detects rise
                needsBitSync = true;
                % peak detection
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
            dthresh_holdT = toc;
            dthresh_mode = 3;
            printArray(dthresh_bits, "derivative thresholding");
        elseif dthresh_mode == 3
            % hold time -- ignore any further data
            if toc - dthresh_holdT > dthresh_hold
                dthresh_mode = 0;
            end
        end

        drawnow

        % make a decision on received bits once both algorithms complete
        % estimate around 6 seconds per pulse
        % short-circuit required!
        if needsBitSync && toc - bitSyncWaitT > bitSyncWait
            dNumBits = size(dthresh_bits, 2);
            vNumBits = size(vthresh_bits, 2);
            if vNumBits < dNumBits
                % value was not enough to trigger low threshold, assume
                % 0 was sent
                vthresh_bits = [vthresh_bits, 0];
            end
            needsBitSync = false;

            % spit out the bit according to this rule
            if vthresh_bits(end) && dthresh_bits(end)
               bit = 1;
            else
               bit = 0;
            end
            fprintf('final bit decision: %i', bit);
            
            %use the detected bit to control drone
            ReceiverToRelay(bit, inAir, a, pT);
            inAir = not(inAir);
            
            if inAir == true
                fprintf('1\n');
            elseif inAir == false
                fprintf('0\n');
            end
        end

        % fixed sampling period
        waitfor(r);
    end
end

function printArray(arr, name)
    fprintf("%s [", name)
    for i = 1:size(arr, 2)
        fprintf("%i ", arr(i))
    end
    fprintf("]\n")
end

function ReceiverToRelay(bit, inAir, a, pT) 
%bit is the signal detected (1 or 0),
%state is the state of the drone, ie. 'air' or 'gnd'
    if (inAir == false) && (bit == 1)
        controlDrone(a, pT);
    elseif (inAir == true) && (bit == 0)
        controlDrone(a, pT);
    else
        fprintf('Invalid command or invalid input data type for receiver-drone\n')
    end
end

function controlDrone(a, pulsewidth)
    %every time this function is called, the land/takeoff button is
    %pressed.
    writeDigitalPin(a, 'D10', 1);
    start(pulsewidth);
    wait(pulsewidth);
    writeDigitalPin(a, 'D10', 0);
end
