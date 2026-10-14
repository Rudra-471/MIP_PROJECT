function expectError(fn, expectedId)
%EXPECTERROR Assert that fn() throws an error with identifier expectedId.
try
    fn();
catch err
    if ~strcmp(err.identifier, expectedId)
        error('test:wrongError', 'Expected error %s but got %s: %s', expectedId, ...
            err.identifier, err.message);
    end
    return;
end
error('test:noError', 'Expected error %s, but no error was thrown.', expectedId);
end
