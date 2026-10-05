function main_control(~,event)
% Defines main control commands for the behaviour (lick, detection, stimuli delivery, ...)


global Main_S_SR association_flag trial_duration quiet_window lick_threshold...
    artifact_window iti camera_flag is_stim is_auditory is_whisker is_light ...
    aud_reward wh_reward light_reward wh_vec aud_vec early_lick...
    stim_flag perf session_start_time lick_flag lick_time trial_start_time trial_end_time trial_time...
    false_alarm_punish_flag false_alarm_timeout early_lick_counter early_lick_punish_flag early_lick_timeout ...
    Stim_S wh_stim_duration wh_scaling_factor aud_stim_duration  aud_stim_amp  aud_stim_freq  Stim_S_SR ...
    Reward_S Trigger_S TTL_S fid_lick_trace mouse_licked_flag reaction_time ...
    trial_started_flag trial_number folder_name handles2give main_gui...
    baseline_window camera_vec...
    deliver_reward_flag ...
    wh_stim_amp wh_stim_amp_mT response_window response_window_start response_window_end...
    perf_and_save_results_flag reward_delivered_flag update_parameters_flag...
    is_reward...
    light_prestim_delay light_duration light_freq light_amp light_power SITrigger_vec...
    context_flag extra_time...
    pink_noise_player brown_noise_player context_block WF_S Opto_S ...
    passive_stim_flag is_passive opto_vec galv_x galv_y wf_cam_vec ...
    ttl1_vec ttl2_vec TTL_info ttl1_edge_times_s ttl1_edge_states ttl1_edge_idx ...
    ttl2_edge_times_s ttl2_edge_states ttl2_edge_idx ...
    ttl1_current_state ttl2_current_state pdco_trial pdco_activation ...
    session_stopping_flag ...
    ttl1_pulse_pending ttl1_pending_edge_times_s ttl1_pending_edge_states ttl1_pulse_active ttl1_pulse_start_time
        
    % prevents main_control from doing anything during shutdown
    if ~isempty(session_stopping_flag) && session_stopping_flag
        return
    end

    %% Timing last lick detection for quiet window.
    % --------------------------------------------

    % A lick is defined as a single scan crossing the lick threshold.
    % if sum(abs(event.Data(1:end-1,1)) < lick_threshold & abs(event.Data(2:end,1)) > lick_threshold)
    % To make the detection more robust to noise, a lick is defined as 8 samples (out
    % of the 10 samples from data available notifications) above the threshold.
    if sum(abs(event.Data(1:end,1)) > lick_threshold) >= 3
        lick_time=tic;
    end

    
    %% Stimulus delivery at trial start.
    % ------------------

    % Trial start: 1. if stim flag ON, 2. no lick in quiet window 3. iti
    % has elapsed since trial_end_time
    if stim_flag && toc(trial_end_time) > iti/1000 + extra_time && toc(lick_time) > quiet_window/1000

        % Reset the stimulation flag
        stim_flag = 0;

        % Update GUI to indicate trial start
        if is_passive
            main_gui.set_online_text('Trial Started (Passive)', [0 0 0]);
        else
            main_gui.set_online_text('Trial Started', [0 0 0]);
        end

        % Start the trial timer
        trial_start_time = tic;
        outputSingleScan(Trigger_S, [1 0 0]);

        % Check if a free reward should be delivered
        if association_flag && ~passive_stim_flag && is_stim
            deliver_reward_flag = 1;
        end

        % Set flags for trial status
        trial_started_flag = 1;
        perf_and_save_results_flag = 0;
        mouse_licked_flag = 0;

        % Record the trial time
        trial_time = toc(session_start_time);

        % Reset TTL edge playback state for this trial
% TTL2 - safe to reset unconditionally every trial (see above).
ttl2_edge_idx = 1;
ttl2_current_state = false;

% TTL1 - if a pulse from a prior (aborted) attempt is still in flight,
% leave it completely alone: it keeps playing against its own clock,
% uninterrupted by this new trial attempt starting. Only anchor a
% freshly pending pulse.
if ~isempty(ttl1_pulse_pending) && ttl1_pulse_pending
    ttl1_edge_times_s = ttl1_pending_edge_times_s;
    ttl1_edge_states = ttl1_pending_edge_states;
    ttl1_edge_idx = 1;
    ttl1_current_state = false;
    ttl1_pulse_start_time = tic;
    ttl1_pulse_active = true;
    ttl1_pulse_pending = false;
    ttl1_pending_edge_times_s = [];
    ttl1_pending_edge_states = [];
end

try
    if ~isempty(TTL_S)
        % Re-assert current state rather than forcing both lines low -
        % must not clobber an in-flight TTL1 pulse.
        outputSingleScan(TTL_S, [double(ttl1_current_state) double(ttl2_current_state)]);
    end
catch
end
    end

    %% Non-blocking TTL edge playback
if isfield(handles2give,'ttl_session') && handles2give.ttl_session && ...
        ~isempty(TTL_S)

    ttl_changed = false;

    % TTL1 - timed against its own independent clock so it plays out
    % fully regardless of trial boundaries/aborts.
    if ~isempty(ttl1_pulse_active) && ttl1_pulse_active
        t_now_ttl1 = toc(ttl1_pulse_start_time);

        while ~isempty(ttl1_edge_times_s) && ttl1_edge_idx <= numel(ttl1_edge_times_s) && ...
                t_now_ttl1 >= ttl1_edge_times_s(ttl1_edge_idx)
            ttl1_current_state = logical(ttl1_edge_states(ttl1_edge_idx));
            ttl1_edge_idx = ttl1_edge_idx + 1;
            ttl_changed = true;
        end

        if ttl1_edge_idx > numel(ttl1_edge_times_s)
            ttl1_pulse_active = false; % pulse fully played out
        end
    end

    % TTL2 - unchanged, still timed against trial_start_time.
    t_now = toc(trial_start_time);

    while ~isempty(ttl2_edge_times_s) && ttl2_edge_idx <= numel(ttl2_edge_times_s) && ...
            t_now >= ttl2_edge_times_s(ttl2_edge_idx)
        ttl2_current_state = logical(ttl2_edge_states(ttl2_edge_idx));
        ttl2_edge_idx = ttl2_edge_idx + 1;
        ttl_changed = true;
    end

    if ttl_changed
        try
            outputSingleScan(TTL_S, [double(ttl1_current_state) double(ttl2_current_state)]);
        catch
        end
    end
end
    
    %% Detecting rewarded licks and trigger reward. 
    % --------------------------------------------

    % sum(abs(event.Data(1:end-1,1))<lick_threshold & abs(event.Data(2:end,1))>lick_threshold) &&... %check if lick
    if trial_started_flag && ~association_flag  &&... %check if currently within a trial
        toc(trial_start_time)>response_window_start && toc(trial_start_time)<response_window_end &&... %check if in response window
        sum(abs(event.Data(1:end,1)) > lick_threshold) >= 3 &&...
        ~sum(abs(event.Data(1:end-1,1))<10000*lick_threshold & abs(event.Data(2:end,1))>10000*lick_threshold) % <- WHY THIS?

        trial_started_flag=0;

        % A lick was detected within the response window: compute hit
        % time/reaction time (same for every trial type), then deliver
        % reward only if this trial's stimulus type is configured as
        % rewarded (aud_reward / wh_reward / light_reward). Catch trials
        % (no stim) never reward, regardless of these flags.
        hit_time=toc(trial_start_time);
        % first_threshold_cross=find(abs(event.Data(1:end-1,1))<lick_threshold & abs(event.Data(2:end,1))>lick_threshold',1,'first');
        first_threshold_cross=find(abs(event.Data(2:end,1))>lick_threshold',1,'first');
        hit_time_adjusted=hit_time-first_threshold_cross/Main_S_SR;
        reaction_time=hit_time_adjusted-(baseline_window)/1000;
        mouse_licked_flag=1;
        perf_and_save_results_flag=1;

        should_reward_this_trial = (is_auditory && aud_reward) || ...
            (is_whisker && wh_reward) || (is_light && light_reward);

        if should_reward_this_trial
            reward_delivery; %deliver reward
        end
    end

    %% Reset flags if no lick detected within the response window (correct rejection, miss trials)
    % --------------------------------------------------------------------------------------------
if trial_started_flag && toc(trial_start_time) > response_window_end && ~association_flag
    % Release reward_vec (useful for proba. whisker reward)
    try
        if ~isempty(Reward_S) %&& isa(Reward_S, 'daq.ni.Session')
            Reward_S.stop();
            Reward_S.release();
        end
    catch
    end
    trial_started_flag = 0;
    perf_and_save_results_flag = 1;
end

    %% Defining performance and update results file
    % ---------------------------------------------

    % Check if results update needed
    if perf_and_save_results_flag
        perf_and_save_results_flag=0;
        early_lick=0;
        
        %Association trials
        if association_flag
            main_gui.set_online_text('Trial Finished', [0 0 0]);
            lick_flag=0;
            perf=6; 

        % All other trials
        else
            % Stimulus trials
            if is_stim && ~mouse_licked_flag && is_whisker
                main_gui.set_online_text('Whisker Miss', [0 0 0]);
                lick_flag=0;
                perf=0;

            elseif is_stim && ~mouse_licked_flag && is_auditory
                main_gui.set_online_text('Auditory Miss', [0 0 0]);
                lick_flag=0;
                perf=1;

            elseif is_stim && mouse_licked_flag && is_whisker
                main_gui.set_online_text('Whisker Hit', [0 0 0]);
                lick_flag=1;
                perf=2;

            elseif is_stim && mouse_licked_flag && is_auditory
                main_gui.set_online_text('Auditory Hit', [0 0 0]);
                lick_flag=1;
                perf=3;

            elseif is_stim && ~mouse_licked_flag && is_light
                main_gui.set_online_text('Light Miss', [0 0 0]);
                lick_flag=0;
                perf=7;

            elseif is_stim && mouse_licked_flag && is_light
                main_gui.set_online_text('Light Hit', [0 0 0]);
                lick_flag=1;
                perf=8;

            % Non-stimulus trials
            elseif ~is_stim && ~mouse_licked_flag
                main_gui.set_online_text('Correct Rejection', [0 0 0]);
                lick_flag=0;
                perf=4;

            elseif ~is_stim && mouse_licked_flag
                main_gui.set_online_text('False Alarm', [0 0 0]);
                lick_flag=1;
                perf=5;

                try
                    if ~isempty(Reward_S)
                        Reward_S.stop();
                        Reward_S.release();
                    end
                catch
                end

                if false_alarm_punish_flag
                    pause(false_alarm_timeout / 1000);
                end

            end
        end
        
        % Set variables to save and namings. Be careful updating here / order & names
        variables_to_save = {trial_number perf trial_time association_flag ...
            quiet_window iti response_window artifact_window baseline_window ...
            trial_duration is_stim is_whisker is_auditory lick_flag reaction_time ...
            wh_stim_duration wh_stim_amp wh_stim_amp_mT wh_scaling_factor wh_reward is_reward ...
            aud_stim_duration aud_stim_amp aud_stim_freq aud_reward early_lick ...
            is_light light_amp light_power light_duration light_freq light_prestim_delay light_reward ...
            context_block pdco_trial pdco_activation};

        variable_saving_names = {'trial_number', 'perf', 'trial_time', 'association_flag', 'quiet_window','iti', ...
            'response_window', 'artifact_window','baseline_window','trial_duration', ...
            'is_stim', 'is_whisker', 'is_auditory', 'lick_flag', 'reaction_time', ...
            'wh_stim_duration', 'wh_stim_amp', 'wh_stim_amp_mT', 'wh_scaling_factor', 'wh_reward', ...
            'is_reward', ...
            'aud_stim_duration','aud_stim_amp','aud_stim_freq','aud_reward', ...
            'early_lick', ...
            'is_light', 'light_amp','light_power','light_duration','light_freq','light_prestim_delay','light_reward', 'context_block', ...
            'pdco_trial', 'pdco_activation'};

        % Update csv result file
        update_and_save_results_csv(variables_to_save, variable_saving_names);

        if handles2give.opto_session
            global variables_to_save_opto

            variables_names_opto = {'trial_number', 'is_opto', 'is_stim', 'is_auditory', 'is_whisker', 'context_block', ...
                'baseline', 'opto_amp', 'opto_freq', 'opto_duration', 'opto_pulse_width', ...
                'grid_no', 'grid_count', 'coord_AP', 'coord_ML', 'volt_x', 'volt_y', 'bregma_x', 'bregma_y'};

            update_and_save_opto_csv(variables_to_save_opto, variables_names_opto);

        end

        % Reset time and flag
        trial_end_time=tic; %trial end time after reward delivery and results are saved
        update_parameters_flag=1; %update params for next trials

    end

    %% UNCLEAR PART - Detecting early licks (licks between baseline start and stimulus or between light start and stim) <- CHECK THIS
    % Early licks result in aborted trials, before starting a new trial

    if trial_started_flag && toc(trial_start_time) < response_window_start - (artifact_window)/1000 ...
            && sum(abs(event.Data(1:end,1)) > lick_threshold) >= 3

        trial_started_flag = 0;
        early_lick = 1;
        early_lick_counter = early_lick_counter + 1;
        deliver_reward_flag = 0;

        % Stop queued stimulus session
        try
            Stim_S.stop();
        catch
        end

        % Force TTL lines low
% TTL2 forced low/reset - safe, it can never have started yet at this
% point (early licks are only caught during the baseline window).
% TTL1 is deliberately left alone: if a PdCO on-pulse is currently in
% flight, it must keep playing through this abort, not get cut short.
try
    if ~isempty(TTL_S)
        outputSingleScan(TTL_S, [double(ttl1_current_state) 0]);
    end
catch
end

ttl2_current_state = false;
ttl2_edge_idx = 1;

        outputSingleScan(Trigger_S, [0 0 0]);

        if handles2give.opto_session
            try
                Opto_S.stop();
                Opto_S.release();
            catch
            end
        end

        main_gui.set_online_text('Early Lick', [0 0 0]);

        while isprop(Stim_S,'IsRunning') && Stim_S.IsRunning
            pause(0.001);
        end

        try
            Stim_S.release();
        catch
        end

        if early_lick_punish_flag
            pause(early_lick_timeout / 1000);
        end

        pause(2);

        lick_flag = 1;
        perf = 6;

        % Set variables to save and namings. Be careful updating here / order & names
        variables_to_save = {trial_number perf trial_time association_flag ...
            quiet_window iti response_window artifact_window baseline_window ...
            trial_duration is_stim is_whisker is_auditory lick_flag reaction_time ...
            wh_stim_duration wh_stim_amp wh_stim_amp_mT wh_scaling_factor wh_reward is_reward ...
            aud_stim_duration aud_stim_amp aud_stim_freq aud_reward early_lick ...
            is_light light_amp light_power light_duration light_freq light_prestim_delay light_reward ...
            context_block pdco_trial pdco_activation};
        
        variable_saving_names = {'trial_number', 'perf', 'trial_time', 'association_flag', 'quiet_window','iti', ...
            'response_window', 'artifact_window','baseline_window','trial_duration', ...
            'is_stim', 'is_whisker', 'is_auditory', 'lick_flag', 'reaction_time', ...
            'wh_stim_duration', 'wh_stim_amp', 'wh_stim_amp_mT', 'wh_scaling_factor', 'wh_reward', ...
            'is_reward', ...
            'aud_stim_duration','aud_stim_amp','aud_stim_freq','aud_reward', ...
            'early_lick', ...
            'is_light', 'light_amp','light_power','light_duration','light_freq','light_prestim_delay','light_reward', 'context_block', ...
            'pdco_trial', 'pdco_activation'};

        % Update csv result file
        update_and_save_results_csv(variables_to_save, variable_saving_names)
        
        if handles2give.opto_session && ~handles2give.wf_session

            try
                queueOutputData(Opto_S, [opto_vec; galv_x; galv_y]')
                pause(.1)
    
            catch
                disp(['Error preloading Opto_S coords ap ml: ' num2str(AP) ' ' num2str(ML)])
                disp(Opto_S)
            end
            Opto_S.startBackground();
    
        elseif handles2give.opto_session && handles2give.wf_session
           
            try
                queueOutputData(Opto_S, [opto_vec(1:end-1); galv_x(1:end-1); galv_y(1:end-1); wf_cam_vec]')
                pause(.1)
    
            catch
                disp(['Error preloading Opto_S coords ap ml: ' num2str(AP) ' ' num2str(ML)])
                disp(Opto_S)
            end
            Opto_S.startBackground();
        end

        if handles2give.opto_session
            global variables_to_save_opto
            variables_names_opto = {'trial_number', 'is_opto', 'is_stim', 'is_auditory', 'is_whisker', 'context_block', ...
                'baseline', 'opto_amp', 'opto_freq', 'opto_duration', 'opto_pulse_width', ...
                'grid_no', 'grid_count', 'coord_AP', 'coord_ML', 'volt_x', 'volt_y', 'bregma_x', 'bregma_y'};

            update_and_save_opto_csv(variables_to_save_opto, variables_names_opto);
            variables_to_save_opto{1} = variables_to_save_opto{1}+1;

        end
%% recently commented out - not sure

        % trial_number = trial_number + 1;
        % 
        % queueOutputData(Stim_S,[wh_vec; aud_vec; camera_vec;SITrigger_vec]')
        % 
        % Stim_S.startBackground();
        % while ~Stim_S.IsRunning
        %     continue
        % end

        % Reset after early lick
        reaction_time = 0;
        early_lick = 0;
        stim_flag=1;
        trial_end_time=tic; %trial end time after reward delivery and results are saved
        update_parameters_flag=1; %update params for next trials
        
    end

    %% Update parameters for next trial
    % ---------------------------------
    if update_parameters_flag && Stim_S.IsDone &&...
            (~reward_delivered_flag || Reward_S.ScansQueued==0) && ~handles2give.PauseRequested %<- why check reward flag?

        update_parameters_flag=0;

        update_parameters;

    elseif update_parameters_flag && Stim_S.IsDone &&...
            (~reward_delivered_flag || Reward_S.ScansQueued==0) && handles2give.PauseRequested && handles2give.ReportPause

        handles2give.ReportPause=0; %reset
        main_gui.set_online_text('Session Paused', [0 0 0]);

    end

    %% Rewarding the stimulus trials in association mode
    % --------------------------------------------------
    if  association_flag && trial_started_flag && deliver_reward_flag &&...
            toc(trial_start_time)>(light_prestim_delay +baseline_window)/1000

        deliver_reward_flag=0;
        outputSingleScan(Trigger_S,[0 1 0])
        reward_delivered_flag=1;
        outputSingleScan(Trigger_S,[0 0 0]);

        %Reset
        trial_started_flag=0;
        perf_and_save_results_flag=1;

    elseif trial_started_flag && association_flag && ~deliver_reward_flag &&...
            toc(trial_start_time)>(light_prestim_delay + baseline_window)/1000

        trial_started_flag=0;
        perf_and_save_results_flag=1;
    end

end