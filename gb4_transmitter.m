main();

function main()
    % params
    epw = 0.05;
    spw = 0.1;
    lpw = 0.4;
    interval = 10;
    n = 10; % bit count
    
    % init
    a = arduino();
    pT = timer("StartDelay", epw);
    pT.TimerFcn = @(~,~)fprintf('');
    shortT = timer("StartDelay", spw);
    shortT.TimerFcn = @(~,~)disp('sent a 0, waiting..');
    longT = timer("StartDelay", lpw);
    longT.TimerFcn = @(~,~)disp('sent a 1, waiting..');
    iT = timer("StartDelay", interval);
    iT.TimerFcn = @(~,~)fprintf('');

    setRelay(a, 0);

    % main loop
    bitsToSend = randi(2,n,1) - 1;
    for i = 1:n
        %bit = input('enter desired binary output');
        bit = bitsToSend(i);
        modulation(bit, pT, longT, shortT, iT, a);
    end
end

function modulation(bit, pT, longT, shortT, iT, a)
    if bit == '0'
        doSpray(pT, shortT, iT, a);
    elseif bit == '1'
        doSpray(pT, longT, iT, a);
    else
        fprintf('invalid input\n');
    end
end

function doSpray(pulseT, sprayT, intervalT, a)
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
