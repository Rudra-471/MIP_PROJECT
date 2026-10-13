function saveConfusionFigure(metrics, filePath)
% TEST SHIM: writes a marker file instead of a MATLAB figure.
fid = fopen(filePath, 'w'); fprintf(fid, 'confusion %s', mat2str(metrics.confusionMatrix)); fclose(fid);
end
