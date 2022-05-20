main();

function main()
    % init
    % note - 0.3s delay for spray switch on
    pT = timer("StartDelay", 0.3);
    pT.TimerFcn = @(~,~)disp('pulse done');
    dT = timer("StartDelay", 1);
    dT.TimerFcn = @(~,~)disp('waiting done');
    a = 2;
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
    fprintf('current state is %u\n', s);
end
