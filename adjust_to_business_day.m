function d_adj = adjust_to_business_day(d)
    % Modified Following: roll forward, unless it crosses month boundary
    dow = weekday(d);

    if dow == 1        % Sunday
        d_fwd = d + 1; % Monday
    elseif dow == 7    % Saturday
        d_fwd = d + 2; % Monday
    else
        d_adj = d;     % Already a business day
        return;
    end
    
    % Check if rolling forward crosses month boundary
    if month(d_fwd) ~= month(d)
        d_adj = d - (dow == 1)*2 - (dow == 7)*1; % Roll back to Friday
    else
        d_adj = d_fwd;
    end
end