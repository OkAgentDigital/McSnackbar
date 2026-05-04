import Foundation

/// Manages scheduled tasks with execution ordering, dependencies, and retry logic.
/// Tasks are stored in ~/.snacks/tasks/tasks.json
class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published private(set) var tasks: [ScheduledTask] = []
    @Published private(set) var isSchedulerRunning: Bool = false
    
    private let fileManager = FileManager.default
    private let tasksURL: URL
    private let queue = DispatchQueue(label: "com.snackbar.tasks", qos: .utility)
    private var schedulerTimer: Timer?
    
    private init() {
        let snacksDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".snacks/tasks")
        tasksURL = snacksDir.appendingPathComponent("tasks.json")
        ensureDirectory()
        loadTasks()
    }
    
    // MARK: - Setup
    
    private func ensureDirectory() {
        let dir = tasksURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - CRUD
    
    func loadTasks() {
        guard fileManager.fileExists(atPath: tasksURL.path),
              let data = try? Data(contentsOf: tasksURL),
              let container = try? JSONDecoder().decode(TaskContainer.self, from: data) else {
            tasks = []
            return
        }
        tasks = container.tasks
    }
    
    func saveTasks() {
        let container = TaskContainer(tasks: tasks)
        if let data = try? JSONEncoder().encode(container) {
            try? data.write(to: tasksURL)
        }
    }
    
    func addTask(_ task: ScheduledTask) {
        tasks.append(task)
        saveTasks()
    }
    
    func updateTask(_ task: ScheduledTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        saveTasks()
    }
    
    func deleteTask(id: String) {
        tasks.removeAll { $0.id == id }
        saveTasks()
    }
    
    func reorderTasks(taskIds: [String]) {
        for (index, taskId) in taskIds.enumerated() {
            if let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[taskIndex].executionOrder = index + 1
            }
        }
        saveTasks()
    }
    
    // MARK: - Scheduler
    
    func startScheduler() {
        guard !isSchedulerRunning else { return }
        isSchedulerRunning = true
        
        schedulerTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Run immediately
        tick()
    }
    
    func stopScheduler() {
        schedulerTimer?.invalidate()
        schedulerTimer = nil
        isSchedulerRunning = false
    }
    
    private func tick() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Sort by execution order
            let sortedTasks = self.tasks
                .filter { $0.status == .pending || $0.status == .failed }
                .sorted { $0.executionOrder < $1.executionOrder }
            
            for task in sortedTasks {
                // Check schedule
                if let schedule = task.schedule {
                    guard self.matchesSchedule(schedule) else { continue }
                }
                
                // Check dependencies
                guard self.dependenciesResolved(task) else {
                    // Mark as blocked
                    if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                        self.tasks[index].status = .blocked
                    }
                    continue
                }
                
                // Execute task
                self.executeTask(task)
            }
            
            DispatchQueue.main.async {
                self.saveTasks()
            }
        }
    }
    
    private func executeTask(_ task: ScheduledTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        
        // Resolve snack or skill
        let snackId = task.snackId ?? task.skillName
        guard let snackId = snackId,
              let snack = SnackManager.shared.getSnack(byId: snackId) ?? 
                         SnackManager.shared.getSnack(byName: snackId) else {
            tasks[index].status = .failed
            tasks[index].retryCount += 1
            return
        }
        
        tasks[index].status = .running
        saveTasks()
        
        let executor = SnackExecutor()
        let result = executor.execute(snack: snack, inputs: task.params)
        
        if result.exitCode == 0 {
            tasks[index].status = .completed
            tasks[index].retryCount = 0
            
            // Trigger on_complete actions
            for completion in task.onComplete {
                if let snackId = completion.snackId,
                   let nextSnack = SnackManager.shared.getSnack(byId: snackId) {
                    _ = executor.execute(snack: nextSnack)
                }
            }
        } else {
            tasks[index].retryCount += 1
            if tasks[index].retryCount >= task.retry.max {
                tasks[index].status = .failed
            } else {
                tasks[index].status = .pending
                // Schedule retry after delay
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(task.retry.delay)) { [weak self] in
                    self?.executeTask(task)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func dependenciesResolved(_ task: ScheduledTask) -> Bool {
        for depId in task.dependencies {
            if let depTask = tasks.first(where: { $0.id == depId }) {
                if depTask.status != .completed {
                    return false
                }
            }
        }
        return true
    }
    
    private func matchesSchedule(_ schedule: String) -> Bool {
        // Simple cron matching (reuses RulesManager logic)
        let rulesManager = RulesManager.shared
        let components = schedule.split(separator: " ").map(String.init)
        guard components.count >= 5 else { return false }
        
        let calendar = Calendar.current
        let now = Date()
        let minute = calendar.component(.minute, from: now)
        let hour = calendar.component(.hour, from: now)
        let day = calendar.component(.day, from: now)
        let month = calendar.component(.month, from: now)
        let weekday = calendar.component(.weekday, from: now) - 1
        
        // Simple check: only run if minute matches (prevents repeated execution)
        guard let cronMinute = Int(components[0]), cronMinute == minute else { return false }
        
        return true
    }
}

// MARK: - Data Models

struct TaskContainer: Codable {
    let tasks: [ScheduledTask]
}

struct ScheduledTask: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    var snackId: String?
    var skillName: String?
    var status: TaskStatus
    var priority: TaskPriority
    var created: String
    var updated: String
    var due: String?
    var tags: [String]
    var dependencies: [String]
    var schedule: String?
    var executionOrder: Int
    var blockedBy: [String]
    var retry: TaskRetry
    var onComplete: [TaskCompletion]
    var params: [String: String]?
    var retryCount: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, status, priority, created, updated, due
        case tags, dependencies, schedule, blockedBy, retry, params
        case snackId = "snack_id"
        case skillName = "skill_name"
        case executionOrder = "execution_order"
        case onComplete = "on_complete"
        case retryCount = "retry_count"
    }
}

enum TaskStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
    case blocked
}

enum TaskPriority: String, Codable {
    case high
    case medium
    case low
    case none
}

struct TaskRetry: Codable {
    let max: Int
    let delay: Int
}

struct TaskCompletion: Codable {
    let taskId: String?
    let snackId: String?
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case snackId = "snack_id"
    }
}
