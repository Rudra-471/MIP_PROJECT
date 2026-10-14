function root = projectRoot()
%PROJECTROOT Absolute path of the project folder (the folder containing main.m).
root = fileparts(fileparts(mfilename('fullpath')));
end
