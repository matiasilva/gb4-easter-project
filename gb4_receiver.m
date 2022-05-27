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
    pulses = zeros(3);
    for i = 1:3
        pulse = detect(a, u_noise, std_noise);
        pulses(i) = pulse;
    end
    [u_peak, std_peak, u_width, std_width] = postProcess(pulses);
    fprintf('average peak of 1s: %.2fV, std of peak: %.3fV\n', u_peak, std_peak);
    fprintf('average width of 1s from 0.9% of u_peak: %.2fV, std of width: %.3fV\n', u_width, std_width);

    disp('send three zeros')
    pulses = zeros(3);
    for i = 1:3
        pulse = detect(a, u_noise, std_noise);
        pulses(i) = pulse;
    end
    [u_peak, std_peak, u_width, std_width] = postProcess(pulses);
    fprintf('average peak of 0s: %.2fV, std of peak: %.3fV\n', u_peak, std_peak);
    fprintf('average width of 0s from 0.9% of u_peak: %.2fV, std of width: %.3fV\n', u_width, std_width);
end

function [u_peak, std_peak, u_width, std_width] = postProcess(pulses, dvsthresh)
    us_peak = [];
    us_width = [];
    for j = 1:3
         pulse = pulses(j);
         [m, i] = max(pulse);
         roll_avg = movmean(pulse, 8);
         us_peak = [us_peak, roll_avg(i)]
         thresh = 0.9 * roll_avg(i);
         % left half
         [~,~,k_min]=unique(round(abs(pulse(1:i)-thresh)),'stable');
         % right half
         [~,~,k_max]=unique(round(abs(pulse(i:end)-thresh)),'stable');
         disp(k_max, k_min);
         us_width = [us_width, k_max - k_min];
    end
    u_peak = mean(us_peak);
    std_peak = std(us_peak);
    u_width = mean(us_width);
    std_width = std(us_width);
end

function pulse = detect(a, u_noise, std_noise)
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
        if isTrackingFall
            isFalling = roll_avg_dvs(end) < 0;
        end
        % ignore any signal below 0.5std of noise
        isAboveNoise = roll_avg_pulse(end) > n_thresh;

        % start condition for fall detection
        if isFalling && isAboveNoise && isTrackingFall
            disp('locked onto fall');
            isTrackingFall = false;
        end

        % loop exit condition
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
