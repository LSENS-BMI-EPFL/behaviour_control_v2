function [light_amp, light_power] = get_light_stim_amp(handles2give, is_retry)
%GET_LIGHT_STIM_AMP Get light amplitude for current light trial.
% Mirrors get_whisker_stim_amp.m, including retry handling: see that
% file's IS_RETRY comment for why this matters.

global light_stim_amp_pool light_stim_amp_pool_idx light_stim_amp_pool_key
global light_stim_amp_last light_stim_power_last

if nargin < 2
    is_retry = false;
end

if is_retry && ~isempty(light_stim_amp_last)
    light_amp = light_stim_amp_last;
    light_power = light_stim_power_last;
    return
end

if handles2give.light_stim_amp_range

    light_stim_amp_list = [
        handles2give.light_stim_amp_1;
        handles2give.light_stim_amp_2;
        handles2give.light_stim_amp_3;
        handles2give.light_stim_amp_4;
        handles2give.light_stim_amp_5];

    light_stim_power_list = [
        handles2give.light_stim_power_1;
        handles2give.light_stim_power_2;
        handles2give.light_stim_power_3;
        handles2give.light_stim_power_4;
        handles2give.light_stim_power_5];

    light_stim_weight_list = [
        handles2give.light_stim_weight_1;
        handles2give.light_stim_weight_2;
        handles2give.light_stim_weight_3;
        handles2give.light_stim_weight_4;
        handles2give.light_stim_weight_5];

    valid_idx = light_stim_weight_list > 0;

    light_stim_amp_list = light_stim_amp_list(valid_idx);
    light_stim_power_list = light_stim_power_list(valid_idx);
    light_stim_weight_list = round(light_stim_weight_list(valid_idx));

    if isempty(light_stim_amp_list) || sum(light_stim_weight_list) == 0
        light_amp = handles2give.light_stim_amp_1;
        light_power = handles2give.light_stim_power_1;
        light_stim_amp_last = light_amp;
        light_stim_power_last = light_power;
        return
    end

    current_key = sprintf('%g_', [ ...
        light_stim_amp_list(:); ...
        light_stim_power_list(:); ...
        light_stim_weight_list(:)]);

    if isempty(light_stim_amp_pool) || isempty(light_stim_amp_pool_idx) || ...
            light_stim_amp_pool_idx > numel(light_stim_amp_pool) || ...
            isempty(light_stim_amp_pool_key) || ~strcmp(current_key, light_stim_amp_pool_key)

        light_stim_amp_pool = [];
        for i = 1:numel(light_stim_amp_list)
            light_stim_amp_pool = [light_stim_amp_pool; repmat(i, light_stim_weight_list(i), 1)];
        end
        light_stim_amp_pool = light_stim_amp_pool(randperm(numel(light_stim_amp_pool)));
        light_stim_amp_pool_idx = 1;
        light_stim_amp_pool_key = current_key;
    end

    selected_idx = light_stim_amp_pool(light_stim_amp_pool_idx);
    light_amp = light_stim_amp_list(selected_idx);
    light_power = light_stim_power_list(selected_idx);
    light_stim_amp_pool_idx = light_stim_amp_pool_idx + 1;

else
    light_amp = handles2give.light_stim_amp_1;
    light_power = handles2give.light_stim_power_1;
end

light_stim_amp_last = light_amp;
light_stim_power_last = light_power;

end