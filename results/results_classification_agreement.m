function results_classification_agreement(ouput_folder, varargin)

    % Get special folder 'Documents' as char
    if ismac
        doc_path = char(java.lang.System.getProperty('user.home'));
        doc_path = fullfile(doc_path,'Documents');
    else
        doc_path = char(getSpecialFolder('MyDocuments'));
    end

    % Get merged classifications
    if isempty(varargin)
        folder = uigetdir(doc_path,'Select one Merged Classification folder');
    else
        if exist(varargin{1},'dir')
            folder = varargin{1};
        else
            folder = uigetdir(doc_path,'Select one Merged Classification folder'); 
        end
    end
    if isnumeric(folder)
        return;
    end
    files = dir(fullfile(folder,'*.mat'));
    if isempty(files)
        errordlg('No merged classifiers found.','Error');
        return;
    end
    
    % Check if folder is correct
    try
        load(fullfile(folder,files(1).name));
    catch
        errordlg('Cannot load merged classifier file','Error');
        return;
    end
    if ~exist('classification_configs','var')
        errordlg('The specified folder does not contain classification_configs files','Error');
        return;
    end
    
    % Sort files
    queue = zeros(length(files),1);
    for i = 1:length(files)
        tmp = strsplit(files(i).name,{'merged_','.mat'});
        queue(i) = str2double(tmp{2});
    end
    [~,idx] = sort(queue);
    files = files(idx);
    
    ids = zeros(1,length(classification_configs.ALL_TAGS));
    for i = 1:length(ids)
        ids(i) = classification_configs.ALL_TAGS{i}{3};
    end
    
    %% Compute confusion matrices and statistics 
    h = waitbar(0,strcat('Computing agreements 1/',num2str(length(files))),'Name','Confusion Matrix');
    cmatrix = 100*eye(length(files));
    for iter = 1:length(files)
        %fprintf('Computing agreements. Iteration %d/%d...\n',iter,length(files));
        
        load(fullfile(folder,files(1).name));
        class_map_1 = classification_configs.CLASSIFICATION.class_map;
        segs = length(class_map_1);
        collect = {};
        % find number of segs per class (including undefined)
        per_strat = zeros(1,length(ids));
        for i = 1:length(ids)
            per_strat(i) = length(find(class_map_1==ids(i)));
        end
        
        % Each loop will find agreement of class_map_1 ---> class_map_x
        for i = 1:length(files)
            load(fullfile(folder,files(i).name));
            class_map_x = classification_configs.CLASSIFICATION.class_map;
            %we have the same thus move on the next one
            if isequal(files(1).name,files(i).name)
                continue;
            end       
            
            [confusion_matrix,order] = confusionmat(class_map_1,class_map_x,'order',ids);
            
            
            diagonal = diag(confusion_matrix);
            % overall agreement (numeric)
            overall_agreement_num = sum(diagonal);
            % overall agreement (percentage)
            overall_agreement_per =  100 * ( overall_agreement_num / segs );
            % agreement per strategy (numeric)
            per_strat_num = zeros(length(order),1);
            for j = 1:length(order)
                per_strat_num(j) = diagonal(j);
            end
            % agreement per strategy (percentage)
            per_strat_per = zeros(length(order),1);
            for j = 1:length(order)
                per_strat_per(j) = 100 * ( per_strat_num(j) / per_strat(j) );
            end
            % collect the results
            collect{i-1,1} = 'confusion matrix';
            collect{i-1,2} = confusion_matrix;
            collect{i-1,3} = 'agreement [numeric, percentage]';
            collect{i-1,4} = [overall_agreement_num, overall_agreement_per];
            collect{i-1,5} = 'agreement per strategy (numeric)';
            collect{i-1,6} = per_strat_num;
            collect{i-1,7} = 'agreement per strategy (percentage)';
            collect{i-1,8} = per_strat_per;
            
            if i + iter -1 <= size(cmatrix,2)
                cmatrix(iter, i + iter -1) = overall_agreement_per;
            else
                % start from the beginning
                cmatrix(iter, i - size(cmatrix,2) +iter-1) = overall_agreement_per;
            end
        end    
        
        %% Export everything
        %fprintf('Saving & exporting results...\n');
        
        number = strsplit(files(1).name,{'merged_','.mat'});
        save(fullfile(ouput_folder,strcat('collect_',number{2},'.mat')),'collect');
        
        %form the first column
        names = {};
        for i = 1:length(files)
            fileName = strsplit(files(i).name,'.mat');
            names = [names fileName{1}];
        end
        tags = cell(length(classification_configs.ALL_TAGS),1);
        for i = 1:length(tags)
            tags{i} = classification_configs.ALL_TAGS{i}{2};
        end
        col_names = {'Agreement';'Numeric';'Percentage';'Overall Numeric';'Overall Percentage'};
        column = cell(length(tags)+1,1);
        for i = 1:length(tags)
            column{i+1} = tags{i};
        end
        column = [column ; col_names];
        %form the main table
        table_all = {};
        for i = 1:size(collect,1)
            table = [tags' ; num2cell(collect{i,2}) ; tags' ; num2cell(collect{i,6})' ; num2cell(collect{i,8})'];
            table{end+2,1} = [];
            table{end-1,1} = strcat(num2str(collect{i,4}(1)),'/',num2str(segs));
            table{end,1} = collect{i,4}(2);
            %put everything together
            table = [column,table];
            table{1,1} = strcat(names{1},'--',names{i+1});

            gap_line = cell(1,size(table,2));
            table_all = [table_all ; table ; gap_line];
        end
        table_all = table_all(1:end-1,:); %remove last empty row
        %write to CSV-file (.csv)
        header = ['Reference', tags'];
        subheader = [names{1}, num2cell(per_strat)];
        table_all = [header ; subheader ; gap_line ; table_all]; 
        table_all = cell2table(table_all);
        writetable(table_all,fullfile(ouput_folder,strcat('agreement_',number{2},'.csv')),'WriteVariableNames',0);
        
        %finally move the first element to the last place
        files(end+1) = files(1);
        files(1) = [];
        
        h = waitbar(iter/length(files),h,strcat('Computing agreements ',num2str(iter),'/',num2str(length(files))));
    end
    
    waitbar(1,h,'Finalizing');
    
    %export the confusion matrix
    column = {};
    for i = 1:length(files)
        tmp = strsplit(files(i).name,'.mat');
        column = [column; tmp{1}];
    end
    header = ['Confusion Matrix',column'];
    table = [column,num2cell(cmatrix)];
    table = [header;table];
    table = cell2table(table);
    save(fullfile(ouput_folder,'confusion_matrix.mat'),'cmatrix');
    writetable(table,fullfile(ouput_folder,'confusion_matrix.csv'),'WriteVariableNames',0);
    
    %export confusion matrix as image
    xylabels = {};
    for i = 1:length(files)
        xylabels = [xylabels,strcat('c',num2str(i))];
    end
    delete(h)
    f = imagesc_adv(cmatrix,'colorbar','on','colormap_range',[0 100],'XTickLabel',xylabels,'YTickLabel',xylabels);
    if isempty(f)
        errordlg('Cannot generate image. x-axis size can be up to 676.','Error');
        return
    else
        [FontName, FontSize, LineWidth, Export, ExportStyle] = parse_configs;
        export_figure(f, ouput_folder, 'confusion_matix_icon', Export, ExportStyle);
        delete(f)
    end   
end

