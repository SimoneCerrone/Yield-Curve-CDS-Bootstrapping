function q_dates = generate_quarterly_dates(t0, Te)
% quarterly dates from t0+3M to Te (Act/360)
% Adjusted to next business day if date falls on weekend

dv0     = datevec(t0);
q_dates = [];
q = 1;
while true
    m_abs = dv0(2) + 3*q;
    y_add = floor((m_abs-1)/12);
    m_new = mod(m_abs-1,12) + 1;
    d = datenum(dv0(1)+y_add, m_new, dv0(3));
    if d > Te, break; end
    q_dates(end+1,1) = adjust_to_business_day(d);
    q = q + 1;
end
if isempty(q_dates) || q_dates(end) < Te
    q_dates(end+1,1) = adjust_to_business_day(Te);
end
end

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