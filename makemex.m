%======================================================================
% This Matlab script generates a clean C function for the 2d gait model
% It also compiles the Matlab MEX interface.
%
% For python, maybe:
%   - write this script in python
%   - python application should call the C function gait2dp.c
%   - use "gcc" or "cc" to run the C compiler, not "mex"
%======================================================================
function makemex
	clear mex

    % Use Autolev to generate C code for the multibody dynamics.
	[~,computername] = system('hostname');
	if strfind(computername,'LRI-102855')
		autolev = 'C:\Program Files\Autolev\al.exe';
        warning('off', 'all');			% don't warn me if I try to delete a file that does not exist
        delete('gait2dp_raw.c');		% we need to delete the .c and .in files so Autolev won't ask for overwrite permission
        delete('gait2dp_raw.in');    
        warning('on', 'all');
        fprintf('Autolev is generating C code...\n');
        fprintf('Hit CTRL-C if this does not complete within 10 seconds (this means there is an error in the Autolev source)\n');
        system(['"' autolev '" gait2dp.al > nul']);		% double quotes needed because autolev has spaces in its path
        delete('gait2dp_raw.in');   
        % Clean the raw C code to make it a function
        autolevclean;       % the Matlab function autolevclean is included in this file
        delete('gait2dp_raw.c');   
	else
		warning('Autolev is only available on Ton''s computer.  MotionGenesis could be used instead.');
        disp('Using the previously generated C code in gait2dp.c instead');
	end
	
	% Compile and link the C code
    disp('Compiling C code, this takes less than 10 seconds...');
    mex -silent -largeArrayDims gait2dpmex.c gait2dp.c
	
    % Completion message
    disp(['gait2dpmex.' mexext ' is ready.']);

end
%=============================================================================
function autolevclean
	disp('Cleaning C code generated by Autolev...');
    NDOF = 9;

	% open the raw C file that came from Autolev
	fid1 = fopen('gait2dp_raw.c','r');
	if (fid1 == -1)
		error('Could not open gait2dp_raw.c');
	end
	
	% write the clean C file
	fid2 = fopen('gait2dp.c','w');
	if (fid2 == -1)
		error('Could not write gait2dp.c');
	end
	
	% write function header
	fprintf(fid2,'// This file contains C code generated by Autolev\n\n');
	fprintf(fid2,'#include <math.h>\n');
	fprintf(fid2,'#include "gait2dpmex.h"\n');
	fprintf(fid2,'void gait2dp(param_struct* par, double q[NDOF], double qd[NDOF], double qdd[NDOF],\n');
	fprintf(fid2,'   double Vsurface, double QQ[NDOF], double dQQ_dq[NDOF][NDOF],\n');
	fprintf(fid2,'   double dQQ_dqd[NDOF][NDOF], double dQQ_dqdd[NDOF][NDOF],\n');
	fprintf(fid2,'   double grf[6], double dgrf_dq[6][NDOF], double dgrf_dqd[6][NDOF],\n');
	fprintf(fid2,'   double stick[NSTICK][2]) {\n');	
	fprintf(fid2,'   \n');
	
	% write some comments to document the function
	fprintf(fid2,'// Inputs:   \n');
	fprintf(fid2,'//	par.........Struct with model parameters, see gait2dp.h for details.   \n');
	fprintf(fid2,'//	q,qd,qdd....Generalized coordinates, velocities, accelerations   \n');
	fprintf(fid2,'//	Vsurface....Surface velocity at this time   \n');
	fprintf(fid2,'//   \n');
	fprintf(fid2,'// Outputs:   \n');
	fprintf(fid2,'//    QQ...........Joint moments required to produce accelerations qdd at state q,qd\n');
	fprintf(fid2,'//    dQQdq, dQQdqd, dQQdqdd..... Jacobians of QQ with respect to q,qd,qdd   \n');
	fprintf(fid2,'//    GRF.........Fx,Fy,Mz on right foot, Fx,Fy,Mz on left foot   \n');
	fprintf(fid2,'//    stick.......X and Y coordinates of 10 points: trunkCM, hip, Rknee, Rankle, Rheel, Rtoe, Lknee, Lankle, Lheel, Ltoe\n');
	fprintf(fid2,'   \n');
    
	% generate C code to copy q, qd, qdd into scalar variables
	for i = 1:NDOF
		fprintf(fid2,'\tdouble q%1d   = q[%1d];  \n', i,i-1);		
		fprintf(fid2,'\tdouble q%1dp  = qd[%1d]; \n', i,i-1);	
		fprintf(fid2,'\tdouble q%1dpp = qdd[%1d];\n', i,i-1);	
    end
    
    % declare the variables used in the contact force model
    points = {'RHeel','RToe','LHeel','LToe'};
    variables = {'y','d','ydot','xdot','Fx','Fy'};
    for i = 1:numel(points)
        for j = 1:numel(variables)
            fprintf(fid2,'\tdouble %s%s;\n', variables{j}, points{i});
        end
    end
	
	% copy the necessary parts of C code from fid1 to fid2
	copying = 0;
	while ~feof(fid1)
		line = fgetl(fid1);
		if strncmp(line, 'double   Pi,DEGtoRAD,RADtoDEG,z[', 32)
			zlength = line(33:min(findstr(line,']'))-1);
			fprintf(fid2,'\tstatic double z[%d];\n',str2num(zlength));		% make sure there is enough room for all Zs
		end
		if strcmp(line, '/* Evaluate constants */') 				% Z[] code starts here
			copying = 1;
        elseif strcmp(line, '/* Evaluate output quantities */') 	% Z[] code ends here
			copying = 0;
        elseif strcmp(line, '/* Write output to screen and to output file(s) */')   % encoded variables code starts here
			copying = 1;
        elseif strcmp(line, '  Encode[0] = 0.0;') 								   % and stops here
			copying = 0;
        elseif copying
			line = strrep(line, 'par__', 'par->');			% change par__ into par->
			fprintf(fid2,'%s\n',line);
		end
	end
	
	% close the input file
	fclose(fid1);
	
	% close the output file
	fprintf(fid2,'}\n');
	fclose(fid2);

end
