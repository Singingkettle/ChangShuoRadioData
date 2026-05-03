classdef RegionSpectrumCatalog
    %REGIONSPECTRUMCATALOG Source-backed regional spectrum service catalog.
    % 中文说明：提供 CSRD 生产链路中的 RegionSpectrumCatalog 实现。
    %
    % Phase 8 keeps regional regulatory facts in a dedicated catalog layer
    % above the older generic band profiles. FrequencyRangeHz is an
    % occupied-signal containment range in Hz. ExplicitChannelCentersHz, when
    % present, gives valid carrier/channel centers inside that containment
    % range.

    methods (Static)
        function ids = supportedRegionIds()
            % supportedRegionIds - Production declaration in CSRD.
            % 中文说明：supportedRegionIds 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            ids = {'CN', 'US', 'EU', 'JP', 'KR'};
        end

        function catalogs = loadAll()
            % loadAll - Production declaration in CSRD.
            % 中文说明：loadAll 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            ids = csrd.catalog.spectrum.RegionSpectrumCatalog.supportedRegionIds();
            catalogs = cell(1, numel(ids));
            for k = 1:numel(ids)
                catalogs{k} = csrd.catalog.spectrum.RegionSpectrumCatalog.load(ids{k});
            end
        end

        function catalog = load(regionId)
            % load - Production declaration in CSRD.
            % 中文说明：load 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            regionId = upper(char(string(regionId)));
            switch regionId
                case 'CN'
                    catalog = buildCnCatalog();
                case 'US'
                    catalog = buildUsCatalog();
                case 'EU'
                    catalog = buildEuCatalog();
                case 'JP'
                    catalog = buildJpCatalog();
                case 'KR'
                    catalog = buildKrCatalog();
                otherwise
                    error('CSRD:Spectrum:UnsupportedRegion', ...
                        'Unsupported RegionId "%s". Supported regions: %s.', ...
                        regionId, strjoin(csrd.catalog.spectrum.RegionSpectrumCatalog.supportedRegionIds(), ', '));
            end
            csrd.catalog.spectrum.RegulatoryValidator.validateCatalog(catalog);
        end
    end
end


function catalog = buildCnCatalog()
    % buildCnCatalog - Production declaration in CSRD.
    % 中文说明：buildCnCatalog 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
authority = 'Ministry of Industry and Information Technology';
refs = {'https://www.miit.gov.cn/gyhxxhb/jgsj/cyzcyfgs/bmgz/wxdl/art/2023/art_1e98823e689f42ca9ed14dcb6feec07a.html'};
catalog = mkCatalog('CN', 'China', authority, refs);
catalog.Bands = [
    band(catalog, 'CN_AM_MW', 'Tier1', [526.5e3 1606.5e3], 'Broadcast', 'AM medium-wave broadcast', 'Primary', 'Simplex', 9e3, 531e3:9e3:1602e3, {9e3}, {'DSBAM','SSBAM'}, 'Continuous', 0.8, 'StandardMapping', refs)
    band(catalog, 'CN_FM_BROADCAST', 'Tier1', [87e6 108e6], 'Broadcast', 'VHF FM broadcast', 'Primary', 'Simplex', 100e3, [], {180e3, 200e3}, {'FM'}, 'Continuous', 1.0, 'StandardMapping', refs)
    band(catalog, 'CN_DTMB_UHF', 'Tier1', [470e6 694e6], 'Broadcast', 'DTMB-like terrestrial television', 'Primary', 'Simplex', 8e6, [], {8e6}, {'OFDM','QAM','VSBAM'}, 'Continuous', 0.5, 'EngineeringApproximation', refs)
    band(catalog, 'CN_LAND_MOBILE_VHF', 'Tier1', [138e6 174e6], 'LandMobile', 'VHF land mobile voice/data', 'Primary', 'Simplex', 12.5e3, [], {12.5e3, 25e3}, {'FM','FSK','GFSK'}, 'Burst', 0.45, 'EngineeringApproximation', refs)
    band(catalog, 'CN_LAND_MOBILE_UHF', 'Tier1', [350e6 470e6], 'LandMobile', 'UHF land mobile/trunking voice/data', 'Primary', 'Simplex', 12.5e3, [], {12.5e3, 25e3, 200e3}, {'FM','FSK','GFSK','QAM'}, 'Burst', 0.45, 'EngineeringApproximation', refs)
    band(catalog, 'CN_IMT_700', 'Tier1', [758e6 788e6], 'Mobile', '700 MHz public mobile downlink', 'Primary', 'FDDDownlink', 100e3, [], {5e6, 10e6, 20e6}, {'OFDM','QAM'}, 'Scheduled', 0.7, 'StandardMapping', refs)
    band(catalog, 'CN_IMT_1800', 'Tier1', [1805e6 1880e6], 'Mobile', '1800 MHz public mobile downlink', 'Primary', 'FDDDownlink', 100e3, [], {5e6, 10e6, 20e6}, {'OFDM','QAM'}, 'Scheduled', 0.65, 'StandardMapping', refs)
    band(catalog, 'CN_IMT_2600', 'Tier1', [2515e6 2675e6], 'Mobile', '2.6 GHz IMT TDD', 'Primary', 'TDD', 100e3, [], {10e6, 20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 0.8, 'StandardMapping', refs)
    band(catalog, 'CN_NR_N78', 'Tier1', [3300e6 3600e6], 'Mobile', '3.5 GHz NR/IMT', 'Primary', 'TDD', 100e3, [], {20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 1.0, 'StandardMapping', refs)
    band(catalog, 'CN_NR_N79', 'Tier1', [4800e6 5000e6], 'Mobile', '4.9 GHz NR/IMT', 'Primary', 'TDD', 100e3, [], {20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 0.75, 'StandardMapping', refs)
    band(catalog, 'CN_IMT_6GHZ', 'Tier2', [6425e6 7125e6], 'Mobile', '6 GHz IMT-style broadband', 'Primary', 'TDD', 100e3, [], {20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 0.35, 'EngineeringApproximation', refs)
    band(catalog, 'CN_ISM_24', 'Tier1', [2400e6 2483.5e6], 'ISM', '2.4 GHz WLAN/Bluetooth/Zigbee/ISM', 'Shared', 'Simplex', 5e6, [], {1e6, 2e6, 20e6, 40e6}, {'OFDM','GFSK','OQPSK'}, 'Burst', 0.9, 'StandardMapping', refs)
    band(catalog, 'CN_ISM_58', 'Tier1', [5725e6 5850e6], 'ISM', '5.8 GHz WLAN/ISM/SRD', 'Shared', 'Simplex', 5e6, [], {20e6, 40e6}, {'OFDM'}, 'Burst', 0.65, 'StandardMapping', refs)
    band(catalog, 'CN_SRD_433', 'Tier1', [433.05e6 434.79e6], 'ShortRangeDevice', '433 MHz short-range devices', 'Shared', 'Simplex', 25e3, [], {12.5e3, 25e3, 100e3}, {'OOK','FSK','GFSK'}, 'Burst', 0.4, 'EngineeringApproximation', refs)
    ];
end


function catalog = buildUsCatalog()
    % buildUsCatalog - Production declaration in CSRD.
    % 中文说明：buildUsCatalog 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
authority = 'Federal Communications Commission / NTIA';
refs = {'https://www.ecfr.gov/current/title-47/chapter-I/subchapter-A/part-2/subpart-B/section-2.106', ...
    'https://www.ntia.gov/publications/redbook-manual'};
catalog = mkCatalog('US', 'United States', authority, refs);
catalog.Bands = [
    band(catalog, 'US_AM_MW', 'Tier1', [530e3 1710e3], 'Broadcast', 'AM broadcast', 'Primary', 'Simplex', 10e3, 540e3:10e3:1700e3, {10e3}, {'DSBAM','SSBAM'}, 'Continuous', 0.65, 'StandardMapping', refs)
    band(catalog, 'US_FM_BROADCAST', 'Tier1', [88e6 108e6], 'Broadcast', 'FM broadcast', 'Primary', 'Simplex', 200e3, 88.1e6:200e3:107.9e6, {180e3, 200e3}, {'FM'}, 'Continuous', 0.8, 'StandardMapping', refs)
    band(catalog, 'US_ATSC_UHF', 'Tier1', [470e6 608e6], 'Broadcast', 'ATSC-like terrestrial television', 'Primary', 'Simplex', 6e6, [], {6e6}, {'VSBAM','OFDM','QAM'}, 'Continuous', 0.45, 'EngineeringApproximation', refs)
    band(catalog, 'US_LAND_MOBILE_VHF', 'Tier1', [150e6 174e6], 'LandMobile', 'VHF land mobile', 'Primary', 'Simplex', 12.5e3, [], {12.5e3, 25e3}, {'FM','FSK','GFSK'}, 'Burst', 0.35, 'EngineeringApproximation', refs)
    band(catalog, 'US_LAND_MOBILE_UHF', 'Tier1', [450e6 470e6], 'LandMobile', 'UHF land mobile', 'Primary', 'Simplex', 12.5e3, [], {12.5e3, 25e3, 200e3}, {'FM','FSK','GFSK','QAM'}, 'Burst', 0.35, 'EngineeringApproximation', refs)
    band(catalog, 'US_ISM_915', 'Tier1', [902e6 928e6], 'ISM', '902-928 MHz ISM/LPWAN/SRD', 'Shared', 'Simplex', 100e3, [], {125e3, 500e3, 1e6}, {'FSK','GFSK','OQPSK'}, 'Burst', 0.5, 'EngineeringApproximation', refs)
    band(catalog, 'US_MOBILE_700', 'Tier1', [746e6 806e6], 'Mobile', '700 MHz mobile broadband', 'Primary', 'FDDDownlink', 100e3, [], {5e6, 10e6, 20e6}, {'OFDM','QAM'}, 'Scheduled', 0.55, 'StandardMapping', refs)
    band(catalog, 'US_PCS_AWS', 'Tier1', [1930e6 2200e6], 'Mobile', 'PCS/AWS mobile downlink', 'Primary', 'FDDDownlink', 100e3, [], {5e6, 10e6, 20e6}, {'OFDM','QAM'}, 'Scheduled', 0.65, 'StandardMapping', refs)
    band(catalog, 'US_CBRS', 'Tier1', [3550e6 3700e6], 'Mobile', 'CBRS broadband radio service', 'Shared', 'TDD', 100e3, [], {10e6, 20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 0.75, 'StandardMapping', refs)
    band(catalog, 'US_C_BAND', 'Tier1', [3700e6 3980e6], 'Mobile', 'C-band 5G broadband', 'Primary', 'TDD', 100e3, [], {20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 0.75, 'StandardMapping', refs)
    band(catalog, 'US_ISM_24', 'Tier1', [2400e6 2483.5e6], 'ISM', '2.4 GHz WLAN/ISM', 'Shared', 'Simplex', 5e6, [], {1e6, 2e6, 20e6, 40e6}, {'OFDM','GFSK','OQPSK'}, 'Burst', 0.85, 'StandardMapping', refs)
    band(catalog, 'US_UNII_5G', 'Tier1', [5150e6 5895e6], 'ISM', '5 GHz U-NII/WLAN', 'Shared', 'Simplex', 5e6, [], {20e6, 40e6}, {'OFDM'}, 'Burst', 0.7, 'StandardMapping', refs)
    ];
end


function catalog = buildEuCatalog()
    % buildEuCatalog - Production declaration in CSRD.
    % 中文说明：buildEuCatalog 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
authority = 'CEPT/ECO';
refs = {'https://docdb.cept.org/document/593', 'https://efis.cept.org/'};
catalog = mkCatalog('EU', 'Europe CEPT', authority, refs);
catalog.Bands = [
    band(catalog, 'EU_AM_MW', 'Tier1', [526.5e3 1606.5e3], 'Broadcast', 'AM medium-wave broadcast', 'Primary', 'Simplex', 9e3, 531e3:9e3:1602e3, {9e3}, {'DSBAM','SSBAM'}, 'Continuous', 0.55, 'StandardMapping', refs)
    band(catalog, 'EU_FM_BROADCAST', 'Tier1', [87.5e6 108e6], 'Broadcast', 'FM broadcast', 'Primary', 'Simplex', 100e3, [], {180e3, 200e3}, {'FM'}, 'Continuous', 0.75, 'StandardMapping', refs)
    band(catalog, 'EU_DAB_VHF', 'Tier1', [174e6 240e6], 'Broadcast', 'DAB-like digital radio', 'Primary', 'Simplex', 1.536e6, [], {1.536e6}, {'OFDM','QAM'}, 'Continuous', 0.45, 'EngineeringApproximation', refs)
    band(catalog, 'EU_DVB_UHF', 'Tier1', [470e6 694e6], 'Broadcast', 'DVB-T-like terrestrial television', 'Primary', 'Simplex', 8e6, [], {8e6}, {'OFDM','QAM'}, 'Continuous', 0.5, 'EngineeringApproximation', refs)
    band(catalog, 'EU_PMR446', 'Tier1', [446e6 446.2e6], 'LandMobile', 'PMR446 personal mobile radio', 'Shared', 'Simplex', 6.25e3, [], {6.25e3, 12.5e3}, {'FM','FSK','GFSK'}, 'Burst', 0.35, 'EngineeringApproximation', refs)
    band(catalog, 'EU_SRD_433', 'Tier1', [433.05e6 434.79e6], 'ShortRangeDevice', '433 MHz SRD', 'Shared', 'Simplex', 25e3, [], {12.5e3, 25e3, 100e3}, {'OOK','FSK','GFSK'}, 'Burst', 0.35, 'EngineeringApproximation', refs)
    band(catalog, 'EU_SRD_868', 'Tier1', [863e6 870e6], 'ShortRangeDevice', '868 MHz SRD/LPWAN', 'Shared', 'Simplex', 100e3, [], {125e3, 250e3, 500e3}, {'FSK','GFSK','OQPSK'}, 'Burst', 0.45, 'EngineeringApproximation', refs)
    band(catalog, 'EU_MOBILE_900', 'Tier1', [925e6 960e6], 'Mobile', '900 MHz cellular downlink', 'Primary', 'FDDDownlink', 100e3, [], {5e6, 10e6, 20e6}, {'OFDM','QAM','GMSK'}, 'Scheduled', 0.55, 'StandardMapping', refs)
    band(catalog, 'EU_MOBILE_1800_2100', 'Tier1', [1805e6 2170e6], 'Mobile', '1800/2100 MHz mobile downlink', 'Primary', 'FDDDownlink', 100e3, [], {5e6, 10e6, 20e6}, {'OFDM','QAM'}, 'Scheduled', 0.65, 'StandardMapping', refs)
    band(catalog, 'EU_NR_3500', 'Tier1', [3400e6 3800e6], 'Mobile', '3.5 GHz NR broadband', 'Primary', 'TDD', 100e3, [], {20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 0.85, 'StandardMapping', refs)
    band(catalog, 'EU_ISM_24', 'Tier1', [2400e6 2483.5e6], 'ISM', '2.4 GHz WLAN/ISM', 'Shared', 'Simplex', 5e6, [], {1e6, 2e6, 20e6, 40e6}, {'OFDM','GFSK','OQPSK'}, 'Burst', 0.8, 'StandardMapping', refs)
    band(catalog, 'EU_RLAN_5G', 'Tier1', [5150e6 5875e6], 'ISM', '5 GHz RLAN', 'Shared', 'Simplex', 5e6, [], {20e6, 40e6}, {'OFDM'}, 'Burst', 0.65, 'StandardMapping', refs)
    ];
end


function catalog = buildJpCatalog()
    % buildJpCatalog - Production declaration in CSRD.
    % 中文说明：buildJpCatalog 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
authority = 'Ministry of Internal Affairs and Communications';
refs = {'https://www.tele.soumu.go.jp/e/adm/freq/search/index.htm'};
catalog = mkCatalog('JP', 'Japan', authority, refs);
catalog.Bands = [
    band(catalog, 'JP_AM_MW', 'Tier1', [522e3 1611e3], 'Broadcast', 'AM broadcast', 'Primary', 'Simplex', 9e3, 531e3:9e3:1602e3, {9e3}, {'DSBAM','SSBAM'}, 'Continuous', 0.5, 'StandardMapping', refs)
    band(catalog, 'JP_FM_BROADCAST', 'Tier1', [76e6 95e6], 'Broadcast', 'FM broadcast', 'Primary', 'Simplex', 100e3, [], {180e3, 200e3}, {'FM'}, 'Continuous', 0.75, 'StandardMapping', refs)
    band(catalog, 'JP_ISDB_UHF', 'Tier1', [470e6 710e6], 'Broadcast', 'ISDB-T-like terrestrial television', 'Primary', 'Simplex', 6e6, [], {6e6}, {'OFDM','QAM'}, 'Continuous', 0.45, 'EngineeringApproximation', refs)
    band(catalog, 'JP_LAND_MOBILE', 'Tier1', [150e6 170e6], 'LandMobile', 'VHF land mobile', 'Primary', 'Simplex', 12.5e3, [], {6.25e3, 12.5e3, 25e3}, {'FM','FSK','GFSK'}, 'Burst', 0.35, 'EngineeringApproximation', refs)
    band(catalog, 'JP_MOBILE_700_800', 'Tier1', [773e6 890e6], 'Mobile', '700/800 MHz mobile downlink', 'Primary', 'FDDDownlink', 100e3, [], {5e6, 10e6, 20e6}, {'OFDM','QAM'}, 'Scheduled', 0.55, 'StandardMapping', refs)
    band(catalog, 'JP_MOBILE_1500_2100', 'Tier1', [1475.9e6 2170e6], 'Mobile', '1.5/1.7/2.1 GHz mobile downlink', 'Primary', 'FDDDownlink', 100e3, [], {5e6, 10e6, 20e6}, {'OFDM','QAM'}, 'Scheduled', 0.65, 'StandardMapping', refs)
    band(catalog, 'JP_NR_SUB6', 'Tier1', [3400e6 4100e6], 'Mobile', 'sub-6 GHz NR broadband', 'Primary', 'TDD', 100e3, [], {20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 0.75, 'StandardMapping', refs)
    band(catalog, 'JP_NR_45', 'Tier1', [4500e6 4900e6], 'Mobile', '4.5 GHz NR broadband', 'Primary', 'TDD', 100e3, [], {20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 0.65, 'StandardMapping', refs)
    band(catalog, 'JP_ISM_24', 'Tier1', [2400e6 2497e6], 'ISM', '2.4 GHz WLAN/ISM', 'Shared', 'Simplex', 5e6, [], {1e6, 2e6, 20e6, 40e6}, {'OFDM','GFSK','OQPSK'}, 'Burst', 0.8, 'StandardMapping', refs)
    band(catalog, 'JP_RLAN_5G', 'Tier1', [5150e6 5730e6], 'ISM', '5 GHz RLAN', 'Shared', 'Simplex', 5e6, [], {20e6, 40e6}, {'OFDM'}, 'Burst', 0.6, 'StandardMapping', refs)
    ];
end


function catalog = buildKrCatalog()
    % buildKrCatalog - Production declaration in CSRD.
    % 中文说明：buildKrCatalog 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
authority = 'Ministry of Science and ICT / Korea Law Information Center';
refs = {'https://law.go.kr/LSW/admRulLsInfoP.do?admRulSeq=2100000254700'};
catalog = mkCatalog('KR', 'Korea', authority, refs);
catalog.Bands = [
    band(catalog, 'KR_AM_MW', 'Tier1', [522e3 1611e3], 'Broadcast', 'AM broadcast', 'Primary', 'Simplex', 9e3, 531e3:9e3:1602e3, {9e3}, {'DSBAM','SSBAM'}, 'Continuous', 0.5, 'StandardMapping', refs)
    band(catalog, 'KR_FM_BROADCAST', 'Tier1', [87.5e6 108e6], 'Broadcast', 'FM broadcast', 'Primary', 'Simplex', 100e3, [], {180e3, 200e3}, {'FM'}, 'Continuous', 0.75, 'StandardMapping', refs)
    band(catalog, 'KR_TDMB_VHF', 'Tier1', [174e6 216e6], 'Broadcast', 'T-DMB-like digital radio', 'Primary', 'Simplex', 1.536e6, [], {1.536e6}, {'OFDM','QAM'}, 'Continuous', 0.4, 'EngineeringApproximation', refs)
    band(catalog, 'KR_DTV_UHF', 'Tier1', [470e6 698e6], 'Broadcast', 'terrestrial digital television approximation', 'Primary', 'Simplex', 6e6, [], {6e6}, {'VSBAM','OFDM','QAM'}, 'Continuous', 0.45, 'EngineeringApproximation', refs)
    band(catalog, 'KR_LAND_MOBILE', 'Tier1', [150e6 174e6], 'LandMobile', 'VHF land mobile', 'Primary', 'Simplex', 12.5e3, [], {12.5e3, 25e3}, {'FM','FSK','GFSK'}, 'Burst', 0.35, 'EngineeringApproximation', refs)
    band(catalog, 'KR_MOBILE_800_900', 'Tier1', [869e6 960e6], 'Mobile', '800/900 MHz mobile downlink', 'Primary', 'FDDDownlink', 100e3, [], {5e6, 10e6, 20e6}, {'OFDM','QAM'}, 'Scheduled', 0.55, 'StandardMapping', refs)
    band(catalog, 'KR_MOBILE_1800_2100', 'Tier1', [1840e6 2170e6], 'Mobile', '1.8/2.1 GHz mobile downlink', 'Primary', 'FDDDownlink', 100e3, [], {5e6, 10e6, 20e6}, {'OFDM','QAM'}, 'Scheduled', 0.65, 'StandardMapping', refs)
    band(catalog, 'KR_NR_35', 'Tier1', [3420e6 3700e6], 'Mobile', '3.5 GHz NR broadband', 'Primary', 'TDD', 100e3, [], {20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 0.85, 'StandardMapping', refs)
    band(catalog, 'KR_NR_28', 'Tier2', [26500e6 28900e6], 'Mobile', '28 GHz NR broadband approximation', 'Primary', 'TDD', 100e3, [], {20e6, 40e6}, {'OFDM','QAM'}, 'Scheduled', 0.25, 'EngineeringApproximation', refs)
    band(catalog, 'KR_ISM_24', 'Tier1', [2400e6 2483.5e6], 'ISM', '2.4 GHz WLAN/ISM', 'Shared', 'Simplex', 5e6, [], {1e6, 2e6, 20e6, 40e6}, {'OFDM','GFSK','OQPSK'}, 'Burst', 0.8, 'StandardMapping', refs)
    band(catalog, 'KR_RLAN_5G', 'Tier1', [5150e6 5850e6], 'ISM', '5 GHz RLAN', 'Shared', 'Simplex', 5e6, [], {20e6, 40e6}, {'OFDM'}, 'Burst', 0.6, 'StandardMapping', refs)
    band(catalog, 'KR_SRD_920', 'Tier1', [917e6 923.5e6], 'ShortRangeDevice', '920 MHz SRD/RFID/LPWAN', 'Shared', 'Simplex', 100e3, [], {125e3, 250e3, 500e3}, {'FSK','GFSK','OQPSK'}, 'Burst', 0.4, 'EngineeringApproximation', refs)
    ];
end


function catalog = mkCatalog(regionId, regionName, authority, sourceRefs)
    % mkCatalog - Production declaration in CSRD.
    % 中文说明：mkCatalog 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
catalog = struct( ...
    'RegionId', regionId, ...
    'RegionName', regionName, ...
    'Authority', authority, ...
    'SourceRefs', {sourceRefs}, ...
    'Bands', emptyBandArray());
end


function b = band(catalog, bandId, tier, rangeHz, serviceClass, application, ...
        allocationStatus, duplexMode, rasterHz, explicitCentersHz, bandwidthsHz, ...
        modFamilies, temporalPattern, priorityWeight, evidenceLevel, sourceRefs)
            % band - Production declaration in CSRD.
            % 中文说明：band 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
b = emptyBand();
b.RegionId = catalog.RegionId;
b.RegionName = catalog.RegionName;
b.Authority = catalog.Authority;
b.BandId = bandId;
b.ServiceTier = tier;
b.FrequencyRangeHz = double(rangeHz);
b.ServiceClass = serviceClass;
b.Application = application;
b.AllocationStatus = allocationStatus;
b.DuplexMode = duplexMode;
b.ChannelRasterHz = double(rasterHz);
b.ExplicitChannelCentersHz = double(explicitCentersHz);
b.RecommendedBandwidthsHz = bandwidthsHz;
b.AllowedModulationFamilies = modFamilies;
b.TemporalPattern = temporalPattern;
b.PriorityWeight = double(priorityWeight);
b.SourceRefs = sourceRefs;
b.EvidenceLevel = evidenceLevel;
b.Notes = '';
end


function bands = emptyBandArray()
    % emptyBandArray - Production declaration in CSRD.
    % 中文说明：emptyBandArray 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
bands = repmat(emptyBand(), 0, 1);
end


function b = emptyBand()
    % emptyBand - Production declaration in CSRD.
    % 中文说明：emptyBand 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
b = struct( ...
    'RegionId', '', ...
    'RegionName', '', ...
    'Authority', '', ...
    'BandId', '', ...
    'ServiceTier', '', ...
    'FrequencyRangeHz', [NaN NaN], ...
    'ServiceClass', '', ...
    'Application', '', ...
    'AllocationStatus', '', ...
    'DuplexMode', '', ...
    'ChannelRasterHz', NaN, ...
    'ExplicitChannelCentersHz', [], ...
    'RecommendedBandwidthsHz', {{}}, ...
    'AllowedModulationFamilies', {{}}, ...
    'TemporalPattern', '', ...
    'PriorityWeight', 0, ...
    'SourceRefs', {{}}, ...
    'EvidenceLevel', '', ...
    'Notes', '');
end
