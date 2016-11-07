function generate_results(project_path, name, segmentation_configs, classifications, animals_trajectories_map, b_pressed, groups)
%GENERATE_RESULTS creates results folder tree, forms the final results and
%saves them inside the specific folders

    dir_list = build_results_tree(project_path, b_pressed, name, length(classifications), groups);

    h = waitbar(0,'Generating results...','Name','Results');
    % Variables of interest:
    %Friedman's test p-value (-1 if it is skipped)
    p_ = cell(1,length(classifications));
    %Friedman's test sample data
    mfried_ = cell(1,length(classifications));
    %Friedman's test num of replicates per cell
    nanimals_ = cell(1,length(classifications));
    %Input data (vector)
    vals_ = cell(1,length(classifications)); 
    %Grouping variable (length(x))
    vals_grps_ = cell(1,length(classifications)); 
    %Position of each boxplot in the figure  
    pos_ = cell(1,length(classifications)); 
    switch b_pressed
        case 'Transitions'
            if length(groups) > 1
                for i = 1:length(classifications)
                    [p,mfried,nanimals,vals,vals_grps,pos] = results_transition_counts(segmentation_configs,classifications{i},animals_trajectories_map,1,dir_list{i});
                    p_{i} = p;
                    mfried_{i} = mfried;
                    nanimals_{i} = nanimals;
                    vals_{i} = vals;
                    vals_grps_{i} = vals_grps;
                    pos_{i} = pos;
                    waitbar(i/length(classifications)); 
                end
            else
               for i = 1:length(classifications)
                    [vals,vals_grps,pos] = results_transition_counts(segmentation_configs,classifications{i},animals_trajectories_map,1,dir_list{i});
                    vals_{i} = vals;
                    vals_grps_{i} = vals_grps;
                    pos_{i} = pos;
                    waitbar(i/length(classifications)); 
                end
            end
        case 'Strategies'
             if length(groups) > 1
                for i = 1:length(classifications)
                    [p,mfried,nanimals,vals,vals_grps,pos] = results_strategies_distributions_length(segmentation_configs,classifications{i},animals_trajectories_map,1,dir_list{i});
                    p_{i} = p;
                    mfried_{i} = mfried;
                    nanimals_{i} = nanimals;
                    vals_{i} = vals;
                    vals_grps_{i} = vals_grps;
                    pos_{i} = pos;
                    waitbar(i/length(classifications)); 
                end
            else
               for i = 1:length(classifications)
                    [vals,vals_grps,pos] = results_strategies_distributions_length(segmentation_configs,classifications{i},animals_trajectories_map,1,dir_list{i});
                    vals_{i} = vals;
                    vals_grps_{i} = vals_grps;
                    pos_{i} = pos;
                    waitbar(i/length(classifications)); 
                end
             end 
        case 'Probabilities'
            if length(groups) > 1
                for i = 1:length(classifications)
                    [prob1, prob2] = results_strategies_transition_prob(segmentation_configs,classifications{i},groups,1,dir_list{i});
                    vals_{i} = {prob1,prob2};
                    waitbar(i/length(classifications)); 
                end
            else
               for i = 1:length(classifications)
                    [prob1] = results_strategies_transition_prob(segmentation_configs,classifications{i},groups,1,dir_list{i});
                    vals_{i} = {prob1};
                    waitbar(i/length(classifications)); 
                end
            end  
    end

    %% Generate a summary of the results
    waitbar(1,h,'Finalizing...');
    %output_dir = fileparts(output_dir); % go one dir backwards
    total_trials = sum(segmentation_configs.EXPERIMENT_PROPERTIES{30});
    class_tags = classifications{1}.CLASSIFICATION_TAGS;
    switch b_pressed
        case 'Strategies'
            create_average_figure(vals_,vals_grps_{1},pos_{1},dir_list{end},total_trials,class_tags);
        case 'Transitions'
            create_average_figure(vals_,vals_grps_,pos_,dir_list{end},total_trials,class_tags);
        case 'Probabilities'
            fpath = fullfile(dir_list{end},'pvalues_summary.csv');
            error = create_average_probs(vals_,class_tags,fpath);
            if error
                errordlg('Could not create summary file');
            end
            delete(h);
            return;
    end
    if length(groups) > 1;
        fpath = fullfile(dir_list{end},'pvalues_summary.csv');
        error = create_pvalues_table(p_,class_tags,fpath);
        if error
            errordlg('Could not create summary file');
        end
    end
    delete(h);
end
