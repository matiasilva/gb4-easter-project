main();

function main()
    % init
    % note - 0.3s delay for spray switch on
    a = arduino();
    pT = timer("StartDelay", 0.05);
    pT.TimerFcn = @(~,~)disp('pulse done');
    dT = timer("StartDelay", 0.4);
    dT.TimerFcn = @(~,~)disp('waiting done');
    setRelay(a, 0);
    
    % main loop
    for i = 1:2
        doPulse(pT, a);
        start(dT);
        wait(dT);    
    end
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
