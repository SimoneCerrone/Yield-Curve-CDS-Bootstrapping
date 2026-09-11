function [A, Dp0, PV_bond,ASW_spread, yf_all, zr_all] = ASW_spread_funct(iss_date, t0, mat_date, Cp0, c, face_value, datesSet, dates, discounts)

% Generate annual coupon dates: 31-Mar-2008, 31-Mar-2009, ..., 31-Mar-2012
N_fixed_coupon_dates = yearfrac(iss_date,mat_date,6);
coupon_dates = zeros(N_fixed_coupon_dates,1);
for k = 1:N_fixed_coupon_dates
    coupon_dates(k) = datenum(2007+k, 3, 31);
end

% Accrued interest from issue date (last coupon) to settlement, 30/360 European
last_cpn = iss_date;
next_cpn = coupon_dates(1);
A= c *face_value* yearfrac(last_cpn,t0,6);

% Dirty price = clean price + accrued interest
Dp0 = Cp0 + A;

% Keep only future coupon dates (after settlement)
fut_coupons = coupon_dates(coupon_dates > t0);

% Build zero-rate curve from bootstrapped pillars (ACT/365 basis)
yf_all     = yearfrac(datesSet.settlement,dates,3);
zr_all     = -log(discounts) ./ yf_all;

yf_coupons = yearfrac(datesSet.settlement,fut_coupons,3);

% Adjust coupon dates to business days and compute year fractions from t0
for i=1:length(coupon_dates)
    adj_dates_current=adjust_to_business_day(datenum(coupon_dates(i)));
    new_year_frac(i)=yearfrac(t0,adj_dates_current,3);
end

% Interpolate zero rates at coupon dates and compute discount factors
zr_coupons = interp1(yf_all, zr_all, new_year_frac, ['linear'], 'extrap');
B_coupons  = exp(-zr_coupons .* new_year_frac);

% Discount factor at maturity
yf_mat = yearfrac(datesSet.settlement,mat_date,3);
zr_mat = interp1(yf_all, zr_all, yf_mat, 'linear', 'extrap');
B_mat  = exp(-zr_mat * yf_mat);

% Present value of bond cash flows discounted at risk-free rates
PV_bond = c * face_value* sum(B_coupons) + face_value * B_mat;

% BPV of the Euribor 3M floating leg (quarterly payments, ACT/360)
q_dates = generate_quarterly_dates(t0, mat_date);
yf_q    = yearfrac(datesSet.settlement,q_dates,2);
zr_q    = interp1(yf_all, zr_all, yf_q, 'linear', 'extrap');
B_q     = exp(-zr_q .* yf_q);

% Quarterly year fractions for the floating leg (ACT/360, base 2)
prev_q  = [t0; q_dates(1:end-1)];
tau_q   = yearfrac(prev_q, q_dates, 2);
BPV_flt = face_value * sum(tau_q .* B_q);

% Asset swap spread: s = (PV_bond - Dirty_price) / BPV_floating
ASW_spread = (PV_bond - Dp0) / BPV_flt;

end