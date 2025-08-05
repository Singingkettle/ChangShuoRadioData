# CommunicationBehaviorSimulator 重构说明

## 问题描述

原始的 `CommunicationBehaviorSimulator` 实现存在一个重要的逻辑错误：每帧都会重新分配频率、调制方式等参数，这不符合实际的无线通信场景。

在真实的无线通信系统中：
- **场景级别参数**（在场景初始化时确定，整个场景保持不变）：
  - 调制方式 (PSK, QAM, OFDM等)
  - 发射频点
  - 带宽分配
  - 功率设置
  - 基本传输参数

- **帧级别参数**（每帧动态调整）：
  - 是否发射信号（开/关状态）
  - 发射时机和时长
  - 传输模式（连续/突发/调度）
  - 时域行为控制

## 重构方案

### 1. 架构调整

#### 原始架构问题：
```matlab
stepImpl(frameId, entities, factoryConfigs)
  ├── 每帧重新生成接收机配置
  ├── 每帧重新生成发射机配置
  ├── 每帧重新分配频率
  ├── 每帧重新选择调制方式
  └── 每帧重新设置功率
```

#### 新架构设计：
```matlab
stepImpl(frameId, entities, factoryConfigs)
  ├── 第一帧：initializeScenarioConfigurations()
  │   ├── 生成固定的接收机配置
  │   ├── 生成固定的发射机配置
  │   ├── 执行频率分配（整个场景固定）
  │   ├── 选择调制方式（整个场景固定）
  │   └── 设置功率等级（整个场景固定）
  └── 每帧：generateFrameConfigurations()
      ├── 复制场景级别配置
      ├── 计算传输状态（开/关）
      ├── 更新时域行为
      └── 应用传输模式
```

### 2. 核心变更

#### 2.1 属性重构
```matlab
% 删除的属性
frequencyAllocator, modulationSelector, powerController, interferenceMatrix, resourceMap

% 新增的属性
scenarioTxConfigs      % 场景级别发射机配置（固定）
scenarioRxConfigs      % 场景级别接收机配置（固定）
scenarioGlobalLayout   % 场景级别全局布局（固定）
scenarioInitialized    % 场景初始化标志
```

#### 2.2 方法重构

**场景级别初始化方法：**
- `initializeScenarioConfigurations()` - 场景级别配置初始化
- `generateScenarioReceiverConfigurations()` - 生成固定接收机配置
- `generateScenarioTransmitterConfigurations()` - 生成固定发射机配置
- `performScenarioFrequencyAllocation()` - 执行场景级别频率分配

**帧级别处理方法：**
- `generateFrameConfigurations()` - 生成帧特定配置
- `calculateTransmissionState()` - 计算传输状态
- `updateBurstState()` - 更新突发传输状态
- `updateScheduledState()` - 更新调度传输状态

**传输模式处理：**
- `generateTransmissionPattern()` - 生成传输模式（场景级别）
- `selectTransmissionPatternType()` - 选择传输模式类型

### 3. 工作流程

#### 3.1 场景初始化（第一帧）
1. **接收机配置**：
   - 确定接收机类型和参数
   - 设置采样率和观测范围
   - 配置天线和敏感度参数

2. **发射机配置**：
   - 确定发射机类型和基本参数
   - 生成消息和调制配置
   - 计算所需带宽
   - 生成传输模式模板

3. **频率分配**：
   - 分析总带宽需求
   - 执行频率分配策略
   - 设置频率范围和中心频率

#### 3.2 帧级别处理（每帧）
1. **状态计算**：
   - 基于传输模式计算当前帧状态
   - 确定是否应该发射信号
   - 计算发射时机和时长

2. **模式特定处理**：
   - **连续模式**：始终激活
   - **突发模式**：基于周期和占空比计算
   - **调度模式**：基于时隙分配计算

### 4. 传输模式详解

#### 4.1 连续传输 (Continuous)
```matlab
TransmissionPattern.Type = 'Continuous'
TransmissionPattern.DutyCycle = 1.0
TransmissionState.IsActive = true  % 每帧都激活
```

#### 4.2 突发传输 (Burst)
```matlab
TransmissionPattern.Type = 'Burst'
TransmissionPattern.Duration = 0.05      % 50ms突发长度
TransmissionPattern.BurstPeriod = 0.2    % 200ms周期
TransmissionPattern.DutyCycle = 0.25     % 25%占空比

% 每帧计算：
frameTime = frameId * 0.1
cycleTime = mod(frameTime, BurstPeriod)
TransmissionState.IsActive = (cycleTime < Duration)
```

#### 4.3 调度传输 (Scheduled)
```matlab
TransmissionPattern.Type = 'Scheduled'
TransmissionPattern.TimeSlotDuration = 0.01  % 10ms时隙
TransmissionPattern.FrameLength = 0.1        % 100ms帧长

% 每帧计算：
TransmissionState.IsActive = (mod(frameId, 3) == 0)  % 每3帧激活一次
```

### 5. 配置兼容性

重构后的系统完全兼容现有的配置文件结构：

```matlab
config.FrequencyAllocation.Strategy = 'ReceiverCentric';
config.FrequencyAllocation.MinSeparation = 100e3;
config.ModulationSelection.Strategy = 'Random';
config.TransmissionPattern.DefaultType = 'Continuous';
config.PowerControl.Strategy = 'FixedPower';
config.PowerControl.MaxPower = 30;
```

### 6. 性能优化

- **减少计算量**：频率分配、调制选择等只在场景初始化时执行一次
- **提高一致性**：整个场景使用相同的通信参数，符合实际情况
- **简化逻辑**：帧级别处理只关注时域行为，逻辑更清晰

### 7. 使用示例

```matlab
% 创建通信行为仿真器
config = struct();
config.FrequencyAllocation.Strategy = 'ReceiverCentric';
config.TransmissionPattern.DefaultType = 'Burst';

simulator = csrd.blocks.scenario.CommunicationBehaviorSimulator('Config', config);

% 第一帧：初始化场景级别配置
[txConfigs1, rxConfigs1, layout1] = simulator(1, entities, factoryConfigs);
% 调制方式、频率等已确定且固定

% 后续帧：只更新传输状态
[txConfigs2, rxConfigs2, layout2] = simulator(2, entities, factoryConfigs);
% 调制方式、频率保持不变，只有传输状态可能改变
```

### 8. 验证要点

- 场景初始化后，调制方式在所有帧中保持一致
- 频率分配在所有帧中保持一致
- 功率设置在所有帧中保持一致
- 只有传输状态（IsActive, StartTime, Duration）在帧间变化
- 传输模式行为符合预期（连续、突发、调度）

这个重构确保了 `CommunicationBehaviorSimulator` 的行为符合实际无线通信系统的特性，同时保持了代码的可维护性和扩展性。 