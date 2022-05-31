main();

function main()
    epw = 0.1;
    interval = 10;
    a = arduino();
    
    pT = timer("StartDelay", epw); %set the switching pulse width
    pT.TimerFcn = @(~,~)fprintf('');
    iT = timer("StartDelay", interval);
    iT.TimerFcn = @(~,~)fprintf('');
    
    controlDrone(a, pT);
    start(iT)
    wait(iT);
    controlDrone(a, pT);
end

function ReceiverToRelay(bit, Dstate, a, pT) 
%bit is the signal detected (1 or 0),
%state is the state of the drone, ie. 'air' or 'gnd'
    if (Dstate == 'air') && (bit == 1)
        controlDrone(a, pT)
    elseif (Dstate == 'gnd') && (bit == 0)
        controlDrone(a, pT)
    else
        fprintf('Invalid command or invalid input data type')
        
end

function controlDrone(a, pulsewidth)
    %every time this function is called, the land/takeoff button is
    %pressed.
    writeDigitalPin(a, 'D10', 1);
    start(pulsewidth);
    wait(pulsewidth);
    writeDigitalPin(a, 'D10', 0);
end
