function tf = isOctaveRuntime()
%ISOCTAVERUNTIME True when the code runs under GNU Octave instead of MATLAB.
%   The project targets MATLAB. Octave support exists only so the pipeline
%   can be tested automatically on machines without a MATLAB licence.
tf = exist('OCTAVE_VERSION', 'builtin') ~= 0;
end
