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
		'LA', 'Pronet', 'University of California, Los Angeles', 60, { 'SK1', 'VG1' }
		'OR', 'Pronet', 'University of Oregon', 60, { 'AR1', 'KS1', 'SC1' }
		'BI', 'Pronet', 'Beth Israel Deaconess Medical Center', 60, { 'CE1' }		% Boston
		'NL', 'Pronet', 'Zucker Hillside Hospital', 60, { 'RC1' }					% Queens
		'NC', 'Pronet', 'University of North Carolina at Chapel Hill', 60, { 'AN1', 'RS1', 'DK1', 'SG1' }
		'SD', 'Pronet', 'University of California, San Diego', 60, { 'MK1', 'CA1', 'LK1' }
		'CA', 'Pronet', 'University of Calgary', 60, { 'AC1', 'AB1', 'MR1' }
		'YA', 'Pronet', 'Yale University', 60, { 'MA1', 'JG1' }
		'SF', 'Pronet', 'University of California, San Francisco', 60, { 'MR1', 'JH1' }
		'PA', 'Pronet', 'University of Pennsylvania', 60, { 'IK1', 'NW1' }
		'SI', 'Pronet', 'Icahn School of Medicine at Mount Sinai', 60, { 'RS1' }			% NYC
		'PI', 'Pronet', 'University of Pittsburgh', 60, { 'CP1', 'MD1' }
		'NN', 'Pronet', 'Northwestern University', 60, { 'CK1', 'JO1' }
		'IR', 'Pronet', 'University of California, Irvine', 60, { 'AB1', 'MV1', 'AM1' }
		'TE', 'Pronet', 'Temple University', 60, { 'KK1', 'BB1', 'AC1' }
		'GA', 'Pronet', 'University of Georgia', 60, { 'LB1', 'SH1', 'SJ1', 'DC1' }
		'WU', 'Pronet', 'Washington University in St. Louis', 60, { 'SR1', 'CC1', 'AM1' }
		'HA', 'Pronet', 'Hartford Hospital', 60, { 'DP1', 'JC1' }
		'MT', 'Pronet', 'McGill University', 60, { 'SA1', 'JG1', 'FB1' }		% Montreal
		'KC', 'Pronet', 'King''s College', 50, { 'SK1' }			% London
		'PV', 'Pronet', 'University of Pavia', 50, { 'NB1', 'SD1', 'UP1' }		% Italy
		'MA', 'Pronet', 'Instituto de Investigación Sanitaria Gregorio Marañón', 50, { 'CM1', 'AP1', 'NB1' }	% Madrid
		'CM', 'Pronet', 'Cambridgeshire and Peterborough NHS Foundation Trust', 50, { 'IB1', 'JS1' }		% England
		'MU', 'Pronet', 'University of Munich', 50, { 'AT1', 'BD1', 'SM1' }
		'SH', 'Pronet', 'Shanghai Jiao Tong University School of Medicine', 50, { 'ZQ1' }
		'SL', 'Pronet', 'Seoul National University', 60, { 'SA1', 'CH1' }			% South Korea is 220 V, 60 Hz
		% PRESCIENT
		'ME', 'Prescient', 'University of Melbourne - Orygen', 50, { 'JL1', 'KN1', 'YM1', 'BM1', 'LA1' }
		'CG', 'Prescient', 'Klinik für Psychiatrie und Psychotherapie', 50, { 'JW1' }		% munich? cologne?
		'PE', 'Prescient', 'Telethon Kids Institute', 50, { '' }				% Perth
		'AD', 'Prescient', 'University of Adelaide', 50, { 'SH1', 'AO1' }
		'GW', 'Prescient', 'Gwangju Early Treatment & Intervention Team (GETIT) Clinic', 60, { 'JY1', 'ML1' }	% South Korea
		'SG', 'Prescient', 'Early Psychosis Intervention Programme (EPIP)', 50, { 'JL1', 'BK1' }	% Singapore
		'AM', 'Prescient', 'Academic Medical Centre (AMC)', 50, { '' }		% Amsterdam
		'CP', 'Prescient', 'Center for Clinical Intervention and Neuropsychiatric Schizophrenia Research (CINS)', 50, { 'GA1' ,'AD1' }		% Denmark
		'JE', 'Prescient', 'The University Hospital Jena', 50, { 'II1' }		% Germany
		'LS', 'Prescient', 'Lausanne University Hospital', 50, { 'RJ1' }		% Switzerland
		'BM', 'Prescient', 'University of Birmingham', 50, { 'ML1' }			% England
		'HK', 'Prescient', 'University of Hong Kong', 50, { 'CC1' ,'CC2' ,'CT1', 'MS1', 'CI1' }
	};

end