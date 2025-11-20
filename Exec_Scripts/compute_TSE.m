function [tse] = compute_TSE(fte, nse)
%% COMPUTE_TSE
% Compute Total System Error (TSE) from Flight Technical Error and 
% Navigation System Error
%
% Inputs:
%   fte - Flight Technical Error time series (m), N×1
%   nse - Navigation System Error time series (m), N×1
%
% Outputs:
%   tse - Total System Error time series (m), N×1
%
% Description:
%   TSE is the root-sum-square of FTE and NSE:
%   
%   TSE = sqrt(FTE² + NSE²)
%   
%   Where:
%   - FTE = Path following error (controller tracking performance)
%   - NSE = Navigation sensor error (position measurement uncertainty)
%   
%   TSE represents the total position uncertainty that must be
%   contained within the protected airspace or corridor.
%
% Reference:
%   ICAO Doc 9613 (PBN Manual)
%   FAA Order 8260.58 (RNP Procedures)
%
% Example:
%   fte = [1.2; 1.5; 1.8];  % meters
%   nse = [0.5; 0.6; 0.4];  % meters
%   tse = compute_TSE(fte, nse);
%   % Result: [1.30; 1.61; 1.84] meters
%
% Author: AI Assistant
% Date: 2025-01-18

    %% Input validation
    if length(fte) ~= length(nse)
        error('compute_TSE:DimensionMismatch', ...
              'FTE and NSE must have the same length');
    end
    
    %% Compute TSE using RSS (Root Sum Square)
    tse = sqrt(fte.^2 + nse.^2);
    
    %% Alternative: Conservative approach (max instead of RSS)
    % For extremely safety-critical applications, some standards
    % use maximum instead of RSS:
    % tse_conservative = max(abs(fte), abs(nse));
    
end
