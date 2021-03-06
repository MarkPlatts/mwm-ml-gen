function results_latency_speed_length(segmentation_configs,animals_trajectories_map,figures,output_dir)
% Comparison of full trajectory metrics for 2 groups of N animals over a 
% set of M trials. The generated plots show:
% 1. The escape latency.
% 2. The average movement speed.
% 3. The average path length.

    hw = waitbar(0,'Generating results...','Name','Results');

    % Get features: latency, length, speed
    latency = segmentation_configs.FEATURES_VALUES_TRAJECTORIES(:,9);
    length_ = segmentation_configs.FEATURES_VALUES_TRAJECTORIES(:,10);
    speed = segmentation_configs.FEATURES_VALUES_TRAJECTORIES(:,11);
    vars = [latency' ; speed' ; length_'/100];
    % Get properties: days and trials
    days = segmentation_configs.EXPERIMENT_PROPERTIES{28}; 
    trials_per_session = segmentation_configs.EXPERIMENT_PROPERTIES{30};
    total_trials = sum(trials_per_session);
    % Get output configurations
    [FontName, FontSize, LineWidth, Export, ExportStyle] = parse_configs;

    % For one group:
    if length(animals_trajectories_map)==1
        one_group_metrics(animals_trajectories_map,vars,total_trials,days,trials_per_session,FontName,FontSize,LineWidth,Export,ExportStyle,output_dir);
        delete(hw);
        return
    end    
    
    % Figure properties
    names = {'latency' , 'speed' , 'length'};
    ylabels = {'latency [s]', 'speed [cm/s]', 'path length [m]'};
    log_y = [0, 0, 0];
    % Generate text file for the p-values
    fn = fullfile(output_dir,'animals_metrics_p.txt');
    fileID = fopen(fn,'wt');
    
    for i = 1:size(vars, 1)
        values = vars(i, :);
        data = [];
        groups = [];
        xpos = [];
        d = .1;
        idx = 1;
        pos = zeros(1, 2*total_trials);
        for s = 1:days
            for t = 1:trials_per_session
                for g = 1:2                    
                    pos(idx) = d;
                    d = d + 0.1;
                    idx = idx + 1;
                end
                d = d + 0.07;
            end
            d = d + 0.15;
        end
        
        % Matrix for friedman's multifactor tests
        [animals_trajectories_map,n] = friedman_test(animals_trajectories_map);
        fried = zeros(total_trials*n, 2);                        
        for t = 1:total_trials
            for g = 1:2            
                map = animals_trajectories_map{g};
                tmp = values(map(t, :));                 
                data = [data, tmp(:)'];
                xpos = [xpos, repmat(pos(t*2 - 1 + g - 1), 1, length(tmp(:)))];             
                groups = [groups, repmat(t*2 - 1 + g - 1, 1, length(tmp(:)))];             
                for j = 1:n
                    fried((t - 1)*n + j, g) = tmp(j);
                end
            end            
        end
        
        % Run friedman's test  
        try
            p = friedman(fried, n, 'off');
            str = sprintf('Friedman p-value (%s): %g', ylabels{i}, p);
            fprintf(fileID,'%s\n',str);
            disp(str);          
        catch
            disp('Error on Friedman test. Friedman test is skipped');
        end    
        
        % Export figures data
        box_plot_data(data, groups, output_dir, strcat('animals_',names{i}));
        
        % Generate figures
        if figures
            f = figure;
            set(f,'Visible','off');
            
            boxplot(data, groups, 'positions', pos, 'colors', [0 0 0; .7 .7 .7]);
            faxis = findobj(f,'type','axes');
            set(faxis, 'LineWidth', LineWidth, 'FontSize', FontSize, 'FontName', FontName);

            lbls = {};
            lbls = arrayfun( @(i) sprintf('%d', i), 1:total_trials, 'UniformOutput', 0);     

            set(faxis, 'XLim', [0, max(pos) + 0.1], 'XTick', (pos(1:2:2*total_trials - 1) + pos(2:2:2*total_trials)) / 2, 'XTickLabel', lbls, 'Ylim', [0 max(data)+20], 'FontSize', FontSize, 'FontName', FontName);                 

            if log_y(i)
                set (faxis, 'Yscale', 'log');
            else
                set (faxis, 'Yscale', 'linear');
            end

            ylabel(ylabels{i}, 'FontSize', FontSize, 'FontName', FontName);
            xlabel('trial', 'FontSize', FontSize, 'FontName', FontName);

            h = findobj(faxis,'Tag','Box');
            for j=1:2:length(h)
                 patch(get(h(j),'XData'), get(h(j), 'YData'), [0 0 0]);
            end
            set(h, 'LineWidth', LineWidth);

            h = findobj(faxis, 'Tag', 'Median');
            for j=1:2:length(h)
                 line('XData', get(h(j),'XData'), 'YData', get(h(j), 'YData'), 'Color', [.9 .9 .9], 'LineWidth', LineWidth);
            end

            h = findobj(faxis, 'Tag', 'Outliers');
            for j=1:length(h)
                set(h(j), 'MarkerEdgeColor', [0 0 0]);
            end

            % check significances
            for t = 1:total_trials
                p = ranksum(data(groups == 2*t - 1), data(groups == 2*t));                                
                if p < 0.05
                    if p < 0.01
                        if p < 0.001
                            alpha = 0.001;
                        else
                            alpha = 0.01;
                        end
                    else
                      alpha = 0.05;
                    end
                end
            end

            set(f, 'Color', 'w');
            box off;        
            set(f,'papersize',[8,8], 'paperposition',[0,0,8,8]);
            export_figure(f, output_dir, sprintf('animals_%s', names{i}), Export, ExportStyle);
            close(f);
        end
        waitbar(i/size(vars, 1));
    end 
    fclose(fileID);
    delete(hw);
end

