function [NPV_a, NPV_b] = NPV(dv, AAGR, CF_a, CF_b, yf_all, zr_all, datesSet)

NPV_a = 0; 
NPV_b = 0;

month_count = 1; 
year=1;
month=1;

% Loop over 20 years, 12 months each
for year = 1:20
    
    for month = 1:12
        
        % Payment date is the 19th of each month
        current_date = datenum(dv(1), dv(2) + month_count, 19);
        
        % Interpolate zero rate at payment date and compute discount factor
        yf_current = yearfrac(datesSet.settlement,current_date,3);
        zr_current = interp1(yf_all, zr_all, yf_current, 'linear', 'extrap');
        B_current  = exp(-zr_current * yf_current);
        
        % Accumulate discounted cash flows
        NPV_a = NPV_a + (CF_a * B_current);
        NPV_b = NPV_b + (CF_b * B_current);
        
        month_count = month_count + 1;
        
    end
    
    % Apply AAGR: cash flows grow by 5% each year (effective from March)
    CF_a = CF_a * (1 + AAGR);
    CF_b = CF_b * (1 + AAGR);
    
end