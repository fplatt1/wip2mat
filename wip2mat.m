function wip2mat()
% wip2mat: waehlt eine .wip per Dialog, liest sie mit WITio und speichert
% jede Messung als .mat (Spektren + Achse in nm/eV/cm^-1), Bilder als .mat+PNG,
% Informationstexte als .txt.

    % --- WITio im Pfad? Sonst einmalig auswaehlen ---
    if isempty(which('WITio.read'))
        witioDir = '';
        if ispref('wip2mat', 'witioDir'), witioDir = getpref('wip2mat', 'witioDir'); end
        if isempty(witioDir) || ~isfolder(witioDir)
            witioDir = uigetdir(pwd, 'WITio-Ordner auswaehlen');
            if isequal(witioDir, 0), return; end
            setpref('wip2mat', 'witioDir', witioDir);
        end
        addpath(genpath(witioDir));
    end

    % --- Datei waehlen ---
    [file, folder] = uigetfile({'*.wip', 'WITec Project (*.wip)'}, 'WIP-Datei auswaehlen');
    if isequal(file, 0), return; end
    [~, base] = fileparts(file);
    outDir = fullfile(folder, [base '_export']);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    % --- Einlesen (oeffnet ggf. den Projektmanager: dort ALLE Objekte markieren) ---
    [O_wid, ~, ~] = WITio.read(fullfile(folder, file));

    fprintf('%d Objekte gefunden:\n', numel(O_wid));
    for i = 1:numel(O_wid)
        fprintf('%3d  %-10s  %s\n', i, string(O_wid(i).Type), string(O_wid(i).Name));
    end

    laser_nm = [];  laserAsked = false;

    % --- Export ---
    for i = 1:numel(O_wid)
        w    = O_wid(i);
        typ  = char(string(w.Type));
        name = matlab.lang.makeValidName(sprintf('%02d_%s_%s', i, typ, string(w.Name)));

        switch typ
            case 'TDGraph'
                spectra = w.Data;
                info    = w.Info;
                G       = w.interpret_Graph;
                axisRaw = double(G(:));

                % Einheit raten und bestaetigen lassen
                mn = min(axisRaw); mx = max(axisRaw);
                if mx < 10,                    guess = 2;   % eV
                elseif mn > 200 && mx < 1100,  guess = 1;   % nm
                else,                          guess = 3;   % cm^-1
                end
                units = {'nm', 'eV', 'rel. 1/cm'};
                sel = listdlg('PromptString', ...
                    sprintf('%s: Einheit der Achse? (Werte %.4g bis %.4g)', name, mn, mx), ...
                    'SelectionMode', 'single', 'ListString', units, 'InitialValue', guess);
                if isempty(sel), sel = guess; end
                axisUnit = units{sel};

                % Laserwellenlaenge einmalig abfragen (optional)
                if ~laserAsked
                    a = inputdlg('Laserwellenlaenge in nm (leer = ohne Raman-Umrechnung):', ...
                                 'Anregung', 1, {''});
                    laserAsked = true;
                    if ~isempty(a) && ~isempty(a{1}), laser_nm = str2double(a{1}); end
                    if isnan(laser_nm), laser_nm = []; end
                end

                wavelength_nm = []; energy_eV = []; raman_shift = [];
                switch sel
                    case 1, wavelength_nm = axisRaw;
                    case 2, energy_eV = axisRaw; wavelength_nm = 1239.84198 ./ axisRaw;
                    case 3, raman_shift = axisRaw;
                end
                if ~isempty(laser_nm)
                    if sel == 3, wavelength_nm = 1e7 ./ (1e7/laser_nm - raman_shift); end
                    if isempty(raman_shift), raman_shift = 1e7/laser_nm - 1e7./wavelength_nm; end
                end
                if isempty(energy_eV) && ~isempty(wavelength_nm)
                    energy_eV = 1239.84198 ./ wavelength_nm;
                end

                save(fullfile(outDir, [name '.mat']), 'spectra', 'axisRaw', 'axisUnit', ...
                     'wavelength_nm', 'energy_eV', 'raman_shift', 'laser_nm', 'info', '-v7');

            case {'TDImage', 'TDBitmap'}
                img  = w.Data;
                info = w.Info;
                save(fullfile(outDir, [name '.mat']), 'img', 'info', '-v7');
                f = figure('Visible', 'off');
                imagesc(squeeze(img)); axis image; colorbar;
                exportgraphics(f, fullfile(outDir, [name '.png']));
                close(f);

            case 'TDText'
                try
                    txt = w.Data;
                    if iscell(txt), txt = strjoin(string(txt), newline); end
                    fid = fopen(fullfile(outDir, [name '.txt']), 'w');
                    fwrite(fid, char(string(txt)), 'char'); fclose(fid);
                catch ME
                    warning('%s: Text nicht exportierbar (%s).', name, ME.message);
                end
        end
    end
    fprintf('Fertig, Dateien in %s\n', outDir);
end