main();

function main()
    % init
    a = arduino();
    pT = timer("StartDelay", 0.05);
    pT.TimerFcn = @(~,~)fprintf('');
    shortT = timer("StartDelay", 0.1);
    shortT.TimerFcn = @(~,~)disp('sent a 0, waiting..');
    longT = timer("StartDelay", 0.4);
    longT.TimerFcn = @(~,~)disp('sent a 1, waiting..');
    iT = timer("StartDelay", 10);
    iT.TimerFcn = @(~,~)fprintf('');

    setRelay(a, 0);

    % main loop
    while true
        bit = input('enter desired binary output\n');
        modulation(bit, a, pT, shortT, longT, iT);
    end
end

function modulation(bit, a, pT, shortT, longT, iT)
    if bit == 0
        doSpray(a, pT, shortT, iT);
    elseif bit == 1
        doSpray(a, pT, longT, iT);
    else
        fprintf('invalid input\n');
    end
end

function doSpray(a, pulseT, sprayT, intervalT)
    doPulse(pulseT, a);
    start(sprayT);
    wait(sprayT);
    doPulse(pulseT, a);
    start(intervalT);
    wait(intervalT);
end

function doPulse(t, a)
    setRelay(a, 1);
    start(t);
    wait(t);
    setRelay(a, 0);
end

function setRelay(a, s)
    writeDigitalPin(a, 'D9', s);
    %fprintf('current state is %u\n', s);
end
