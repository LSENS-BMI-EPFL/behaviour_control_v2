function light_stim_weight = get_light_stim_weight(handles2give)
%GET_LIGHT_STIM_WEIGHT Get sum of total light stimulus weights.

if handles2give.light_stim_amp_range
    light_stim_weight = handles2give.light_stim_weight_1+...
        handles2give.light_stim_weight_2+...
        handles2give.light_stim_weight_3+...
        handles2give.light_stim_weight_4+...
        handles2give.light_stim_weight_5;
else
    light_stim_weight = handles2give.light_stim_weight_1;
end

end