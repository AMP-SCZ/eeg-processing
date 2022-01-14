function siteInfo = AMPSCZ_EEG_siteInfo
% List of 2-letter AMPSCZ site identifiers, full names, and power line frequencies.
% Line frequency is assumed by what's typical in country of origin.
%
% USAGE:
% >> siteInfo = AMPSCZ_EEG_siteInfo
%
% Written by: Spero Nicholas, NCIRE
%
% Date Created: 10/14/2021

% lochness is using 'Prescient' and 'Pronet' + 'PrescientXX' & 'PronetXX' folder names

% 	narginchk( 0, 0 )

	% ProNET & PRESCIENT Site IDs
	siteInfo = {
		% ProNET
		'LA', 'Pronet', 'University of California, Los Angeles', 60
		'OR', 'Pronet', 'University of Oregon', 60
		'BI', 'Pronet', 'Beth Israel Deaconess Medical Center', 60		% Boston
		'NL', 'Pronet', 'Zucker Hillside Hospital', 60					% Queens
		'NC', 'Pronet', 'University of North Carolina at Chapel Hill', 60
		'SD', 'Pronet', 'University of California, San Diego', 60
		'CA', 'Pronet', 'University of Calgary', 60
		'YA', 'Pronet', 'Yale University', 60
		'SF', 'Pronet', 'University of California, San Francisco', 60
		'PA', 'Pronet', 'University of Pennsylvania', 60
		'SI', 'Pronet', 'Icahn School of Medicine at Mount Sinai', 60			% NYC
		'PI', 'Pronet', 'University of Pittsburgh', 60
		'NN', 'Pronet', 'Northwestern University', 60
		'IR', 'Pronet', 'University of California, Irvine', 60
		'TE', 'Pronet', 'Temple University', 60
		'GA', 'Pronet', 'University of Georgia', 60
		'WU', 'Pronet', 'Washington University in St. Louis', 60
		'HA', 'Pronet', 'Hartford Hospital', 60
		'MT', 'Pronet', 'McGill University', 60		% Montreal
		'KC', 'Pronet', 'King''s College', 50			% London
		'PV', 'Pronet', 'University of Pavia', 50		% Italy
		'MA', 'Pronet', 'Instituto de Investigación Sanitaria Gregorio Marañón', 50		% Madrid
		'CM', 'Pronet', 'Cambridgeshire and Peterborough NHS Foundation Trust', 50		% England
		'MU', 'Pronet', 'University of Munich', 50
		'SH', 'Pronet', 'Shanghai Jiao Tong University School of Medicine', 50
		'SL', 'Pronet', 'Seoul National University', 60			% South Korea is 220 V, 60 Hz
		% PRESCIENT
		'ME', 'Prescient', 'University of Melbourne - Orygen', 50
		'PE', 'Prescient', 'Telethon Kids Institute', 50				% Perth
		'AD', 'Prescient', 'University of Adelaide', 50
		'GW', 'Prescient', 'Gwangju Early Treatment & Intervention Team (GETIT) Clinic', 60	% South Korea
		'SG', 'Prescient', 'Early Psychosis Intervention Programme (EPIP)', 50	% Singapore
		'AM', 'Prescient', 'Academic Medical Centre (AMC)', 50		% Amsterdam
		'CP', 'Prescient', 'Center for Clinical Intervention and Neuropsychiatric Schizophrenia Research (CINS)', 50		% Denmark
		'JE', 'Prescient', 'The University Hospital Jena', 50		% Germany
		'LS', 'Prescient', 'Lausanne University Hospital', 50		% Switzerland
		'BM', 'Prescient', 'University of Birmingham', 50			% England
		'HK', 'Prescient', 'University of Hong Kong', 50
	};

end