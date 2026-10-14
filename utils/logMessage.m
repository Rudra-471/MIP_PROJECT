function logMessage(level, format, varargin)
%LOGMESSAGE Developer log: prints to the command window and appends to logs/app.log.
%   logMessage('INFO', 'Loaded %d images', n)
%   level is 'INFO', 'WARN' or 'ERROR'. Logging never throws: a log failure
%   must not break the application.

try
    text = sprintf(format, varargin{:});
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    line = sprintf('[%s] %-5s %s', stamp, upper(level), text);
    fprintf('%s\n', line);
    logDir = fullfile(projectRoot(), 'logs');
    if exist(logDir, 'dir') ~= 7
        mkdir(logDir);
    end
    fid = fopen(fullfile(logDir, 'app.log'), 'a');
    if fid > 0
        fprintf(fid, '%s\n', line);
        fclose(fid);
    end
catch
end
end
