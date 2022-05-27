main()

function main()
    a = arduino();

    % init calibration sequence
    calibration(a)
end

function t = createNoiseTimer()
    t = timer;
    t.TimerFcn = @tfcn;
    t.StartDelay = 5;
    t.UserData = true;

    function tfcn(mTimer,~)
        disp('finished measuring noise')
        t.UserData = false;
    end
end

function calibration(a)
    % find avg noise
    disp('measuring noise')
    waitT = createNoiseTimer();
    start(waitT);
    nlevels = [];
    while waitT.UserData
         s = readVoltage(a, 'A0');
         nlevels = [nlevels; s];
    end
    std_noise = std(nlevels);
    u_noise = mean(nlevels);
    fprintf('average noise: %.2fV, std of noise: %.3fV\n', u_noise, std_noise);

    disp('send three ones')
    detect(a, u_noise, std_noise);

    disp('send three zeros')
end

function [u_peak, std_peak, u_width, std_width] = postProcess(pulse, dvsthresh)
end

function detect(a, u_noise, std_noise)
    isDetecting = true;
    isFalling = false;
    isTrackingFall = true;
    pulse = [u_noise];
    dvs = [];
    n_thresh = u_noise + 2*std_noise;
    disp('detecting peak')
    while isDetecting
        tic
        s = readVoltage(a, 'A0');
        % calc derivative
        ds = numdiff(pulse(end), s, toc);
        % aggregate data
        dvs = [dvs; ds];
        pulse = [pulse; s];
        % calc rolling averages
        roll_avg_dvs = movmean(dvs, 10);
        roll_avg_pulse = movmean(pulse, 3);
        
        % ignore rises after first fall
        isFalling = roll_avg_dvs(end) < 0;
        % ignore any signal below 0.5std of noise
        isAboveNoise = roll_avg_pulse(end) > n_thresh;
        if isFalling && isAboveNoise && isTrackingFall
            disp('locked onto fall');
            isTrackingFall = false;
        end

        if isFalling && ~isAboveNoise && ~isTrackingFall
            disp('peak finished')
            isDetecting = false;
        end
    end
    plot(1:size(pulse), pulse);
end

function ds = numdiff(x1, x2, dt)
    ds = (x2-x1)/dt;
end
