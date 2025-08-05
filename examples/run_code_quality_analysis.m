% run_code_quality_analysis - Example script for MATLAB code quality analysis
%
% This script demonstrates how to use the code_quality_checker tool to analyze
% the ChangShuoRadioData project for compliance with MATLAB coding standards,
% documentation completeness, and overall code quality.
%
% Usage Examples:
%   1. Basic analysis of entire project
%   2. Focused analysis of specific files
%   3. Verbose analysis with detailed reporting
%   4. Targeted analysis of core components
%
% Requirements:
%   - MATLAB R2019b or later
%   - Access to tools/code_quality_checker.m
%   - Project files in standard CSRD structure

fprintf('🚀 ChangShuo Radio Data - Code Quality Analysis\n');
fprintf('=' .* ones(1, 60));
fprintf('\n\n');

%% Example 1: Quick Overview Analysis
fprintf('📋 Example 1: Quick Project Overview\n');
fprintf('-' .* ones(1, 40));
fprintf('\n');

try
    % Analyze core CSRD package directory
    results1 = code_quality_checker('Directory', '+csrd', 'Verbose', false);

    fprintf('✅ Quick analysis completed!\n');
    fprintf('📊 Overall Quality Score: %.1f/100\n', results1.QualityScore);
    fprintf('📄 Files analyzed: %d\n', results1.Summary.TotalFiles);
    fprintf('\n');

catch analysisException
    fprintf('❌ Analysis failed: %s\n', analysisException.message);
end

%% Example 2: Detailed Analysis of Core Files
fprintf('📋 Example 2: Core Files Detailed Analysis\n');
fprintf('-' .* ones(1, 40));
fprintf('\n');

% Define core files for detailed analysis
coreFiles = {
             '+csrd/SimulationRunner.m',
             '+csrd/+core/ChangShuo.m',
             '+csrd/+blocks/+physical/+txRadioFront/TRFSimulator.m',
             '+csrd/+blocks/+scenario/ParameterDrivenPlanner.m'
             };

try
    results2 = code_quality_checker('Files', coreFiles, 'Verbose', true);

    fprintf('\n📈 Core Files Quality Summary:\n');

    for i = 1:length(results2.FileAnalysis)
        analysis = results2.FileAnalysis{i};

        if isfield(analysis, 'QualityMetrics')
            [~, fileName] = fileparts(analysis.FilePath);
            avgScore = mean(struct2array(analysis.QualityMetrics));
            fprintf('  📄 %s: %.1f/100\n', fileName, avgScore);
        end

    end

    fprintf('\n');

catch analysisException
    fprintf('❌ Core files analysis failed: %s\n', analysisException.message);
end

%% Example 3: Factory Classes Analysis
fprintf('📋 Example 3: Factory Classes Analysis\n');
fprintf('-' .* ones(1, 40));
fprintf('\n');

try
    % Analyze factory classes specifically
    results3 = code_quality_checker('Directory', '+csrd/+factories', 'Verbose', false);

    fprintf('🏭 Factory Classes Analysis:\n');
    fprintf('📊 Average Quality Score: %.1f/100\n', results3.QualityScore);
    fprintf('📝 Documentation Score: %.1f/100\n', results3.Summary.DocumentationScore);
    fprintf('🏷️ Naming Score: %.1f/100\n', results3.Summary.NamingScore);

    if results3.Summary.DocumentationScore < 80
        fprintf('⚠️  Factory classes need documentation improvement\n');
    end

    fprintf('\n');

catch analysisException
    fprintf('❌ Factory analysis failed: %s\n', analysisException.message);
end

%% Example 4: Configuration System Analysis
fprintf('📋 Example 4: Configuration System Analysis\n');
fprintf('-' .* ones(1, 40));
fprintf('\n');

configFiles = {
               'config/csrd2025/initialize_csrd_configuration.m'
               };

try
    results4 = code_quality_checker('Files', configFiles, 'Verbose', true);

    if ~isempty(results4.FileAnalysis)
        analysis = results4.FileAnalysis{1};

        if isfield(analysis, 'QualityMetrics')
            fprintf('⚙️ Configuration System Quality:\n');
            fprintf('  📝 Documentation: %.1f/100\n', analysis.QualityMetrics.Documentation);
            fprintf('  🏷️ Naming: %.1f/100\n', analysis.QualityMetrics.Naming);
            fprintf('  🏗️ Structure: %.1f/100\n', analysis.QualityMetrics.Structure);
            fprintf('  💬 Comments: %.1f/100\n', analysis.QualityMetrics.Comments);
            fprintf('  ✅ Best Practices: %.1f/100\n', analysis.QualityMetrics.BestPractices);
        end

    end

    fprintf('\n');

catch analysisException
    fprintf('❌ Configuration analysis failed: %s\n', analysisException.message);
end

%% Example 5: Test Files Analysis
fprintf('📋 Example 5: Test Files Quality Check\n');
fprintf('-' .* ones(1, 40));
fprintf('\n');

try
    % Check if tests directory exists
    if exist('tests', 'dir')
        results5 = code_quality_checker('Directory', 'tests', 'Verbose', false);

        fprintf('🧪 Test Files Analysis:\n');
        fprintf('📊 Quality Score: %.1f/100\n', results5.QualityScore);
        fprintf('📄 Test files: %d\n', results5.Summary.TotalFiles);

        if results5.QualityScore > 80
            fprintf('✅ Test files meet quality standards\n');
        else
            fprintf('⚠️  Test files need improvement\n');
        end

    else
        fprintf('⚠️  Tests directory not found\n');
    end

    fprintf('\n');

catch analysisException
    fprintf('❌ Test analysis failed: %s\n', analysisException.message);
end

%% Summary Report
fprintf('📋 Overall Project Quality Assessment\n');
fprintf('-' .* ones(1, 40));
fprintf('\n');

% Calculate overall project metrics (weighted by component importance)
componentWeights = [0.4, 0.3, 0.2, 0.1]; % Core, Factories, Config, Tests
componentScores = [];

% Collect scores from different analyses
if exist('results1', 'var'), componentScores(1) = results1.QualityScore; end
if exist('results3', 'var'), componentScores(2) = results3.QualityScore; end
if exist('results4', 'var'), componentScores(3) = results4.QualityScore; end
if exist('results5', 'var'), componentScores(4) = results5.QualityScore; end

% Calculate weighted overall score
if length(componentScores) >= 3
    overallScore = sum(componentWeights(1:length(componentScores)) .* componentScores);

    fprintf('🏆 FINAL PROJECT QUALITY ASSESSMENT\n');
    fprintf('📊 Overall Quality Score: %.1f/100\n', overallScore);

    if overallScore >= 85
        fprintf('✅ EXCELLENT - Project meets high quality standards\n');
    elseif overallScore >= 70
        fprintf('✅ GOOD - Project meets acceptable quality standards\n');
    elseif overallScore >= 60
        fprintf('⚠️  NEEDS IMPROVEMENT - Several quality issues identified\n');
    else
        fprintf('❌ POOR - Significant quality improvements required\n');
    end

end

%% Recommendations Summary
fprintf('\n🎯 TOP IMPROVEMENT RECOMMENDATIONS:\n');

recommendations = {};

% Collect recommendations from all analyses
if exist('results1', 'var')
    recommendations = [recommendations, results1.Recommendations];
end

if exist('results2', 'var')
    recommendations = [recommendations, results2.Recommendations];
end

if exist('results3', 'var')
    recommendations = [recommendations, results3.Recommendations];
end

% Display unique recommendations
uniqueRecommendations = unique(recommendations);

for i = 1:min(5, length(uniqueRecommendations))
    fprintf('  %d. %s\n', i, uniqueRecommendations{i});
end

%% Next Steps
fprintf('\n📋 NEXT STEPS FOR CODE IMPROVEMENT:\n');
fprintf('  1. Review detailed analysis reports in MATLAB workspace\n');
fprintf('  2. Address high-priority recommendations first\n');
fprintf('  3. Focus on documentation improvements for biggest impact\n');
fprintf('  4. Standardize variable naming across all files\n');
fprintf('  5. Ensure all comments are in English\n');
fprintf('  6. Run analysis regularly during development\n');

fprintf('\n💾 Analysis results saved in workspace variables:\n');
fprintf('  - results1: Core package analysis\n');
fprintf('  - results2: Detailed core files analysis\n');
fprintf('  - results3: Factory classes analysis\n');
fprintf('  - results4: Configuration system analysis\n');
fprintf('  - results5: Test files analysis (if available)\n');

fprintf('\n✅ Code quality analysis completed!\n');
fprintf('📖 For detailed improvement guidelines, see:\n');
fprintf('   docs/code_review_and_improvement_plan.md\n');

%% Additional Analysis Functions

function displayCategoryBreakdown(results)
    % displayCategoryBreakdown - Show detailed breakdown by quality category

    fprintf('\n📈 QUALITY CATEGORY BREAKDOWN:\n');
    fprintf('┌─────────────────┬─────────┬─────────────────────────┐\n');
    fprintf('│ Category        │ Score   │ Status                  │\n');
    fprintf('├─────────────────┼─────────┼─────────────────────────┤\n');

    categories = {'Documentation', 'Naming', 'Structure', 'Comments', 'BestPractices'};
    scores = [results.Summary.DocumentationScore, results.Summary.NamingScore, ...
                  results.Summary.StructureScore, results.Summary.CommentScore, ...
                  results.Summary.BestPracticeScore];

    for i = 1:length(categories)
        status = getQualityStatus(scores(i));
        fprintf('│ %-15s │ %6.1f  │ %-23s │\n', categories{i}, scores(i), status);
    end

    fprintf('└─────────────────┴─────────┴─────────────────────────┘\n');
end

function status = getQualityStatus(score)
    % getQualityStatus - Convert numeric score to status description

    if score >= 90
        status = '🌟 Excellent';
    elseif score >= 80
        status = '✅ Good';
    elseif score >= 70
        status = '⚠️  Needs Improvement';
    elseif score >= 60
        status = '❌ Poor';
    else
        status = '💥 Critical';
    end

end
