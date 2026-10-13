function result = runCase(name, fn)
%RUNCASE Run one test case and return a result struct (name, status, message).
%   fn may throw an error with identifier 'CXR:testSkipped' to mark the
%   case as SKIPPED (e.g. functionality that cannot run under Octave).
try
    fn();
    result = struct('name', name, 'status', 'PASS', 'message', '');
catch err
    if strcmp(err.identifier, 'CXR:testSkipped')
        result = struct('name', name, 'status', 'SKIP', 'message', err.message);
    else
        result = struct('name', name, 'status', 'FAIL', 'message', err.message);
    end
end
fprintf('  %-4s  %s', result.status, name);
if ~isempty(result.message)
    fprintf('  (%s)', strtok(result.message, newline));
end
fprintf('\n');
end
