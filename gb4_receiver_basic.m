interv = 35;
x = [];
t = [];
tic
while (toc<interv)
    b = readVoltage(a, "A0");
    t = [t; toc];
    x = [x; b];
    plot(t, x)
    xlabel('time (s)', 'FontSize', 20)
    ylabel('voltage (V)', 'FontSize', 20)
    title('receiver reads with time', 'FontSize', 20);
    grid ON
    drawnow
end
headers = {'time (s)';'voltage (V)'};
Acat = cat(2, t, x)
T = array2table(Acat,  'VariableNames', headers);
writetable(T, 'height_5cm_2');
