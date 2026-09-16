import SwiftUI

struct SavedProjectsSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if !appState.savedProjects.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    OffsetEyebrow(text: "SAVED PROJECTS")
                    Spacer()
                    Text("Stored on this device")
                        .font(.caption)
                        .foregroundStyle(OffsetTheme.secondaryText)
                }

                ForEach(appState.savedProjects) { project in
                    NavigationLink {
                        SavedProjectDetailView(projectID: project.id)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: project.projectType.icon)
                                .font(.title3)
                                .foregroundStyle(OffsetTheme.emerald)
                                .frame(width: 42, height: 42)
                                .background(OffsetTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(project.name)
                                    .font(.headline)
                                    .foregroundStyle(OffsetTheme.text)
                                Text(project.stickerPriceUSD, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(OffsetTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(OffsetTheme.outline)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("saved-project-row")
                    .offsetCard()
                }
            }
        }
    }
}

struct SaveProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var projectType: ProjectType
    @State private var priceText: String

    private let existingProject: SavedProject?
    private let onSave: (SavedProject) -> Void

    init(
        project: SavedProject? = nil,
        defaultProjectType: ProjectType = .heatPump,
        defaultPriceUSD: Double = 0,
        onSave: @escaping (SavedProject) -> Void
    ) {
        existingProject = project
        _name = State(initialValue: project?.name ?? defaultProjectType.displayName)
        _projectType = State(initialValue: project?.projectType ?? defaultProjectType)
        _priceText = State(initialValue: Self.priceString(project?.stickerPriceUSD ?? defaultPriceUSD))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Project name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("saved-project.name")
                    Picker("Type", selection: $projectType) {
                        ForEach(ProjectType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                }

                Section("Sticker price") {
                    HStack {
                        Text("$")
                        TextField("0", text: Binding(
                            get: { priceText },
                            set: { priceText = Self.sanitizePrice($0) }
                        ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("saved-project.price")
                    }
                }

                Section {
                    Label("Saved projects and checklist progress stay on this device.", systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(OffsetTheme.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(OffsetTheme.canvas)
            .navigationTitle(existingProject == nil ? "Save project" : "Edit project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var parsedPrice: Double? {
        Double(priceText)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (parsedPrice ?? 0) > 0
            && (parsedPrice ?? .infinity) < 10_000_000
    }

    private func save() {
        guard let price = parsedPrice, canSave else { return }
        let now = Date()
        let project = SavedProject(
            id: existingProject?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            projectType: projectType,
            stickerPriceUSD: price,
            createdAt: existingProject?.createdAt ?? now,
            updatedAt: now
        )
        onSave(project)
        dismiss()
    }

    private static func sanitizePrice(_ input: String) -> String {
        var result = ""
        var hasDecimal = false
        var fractionCount = 0
        for character in input {
            if character.isNumber {
                if hasDecimal {
                    guard fractionCount < 2 else { continue }
                    fractionCount += 1
                }
                result.append(character)
            } else if character == ".", !hasDecimal {
                hasDecimal = true
                result.append(character)
            }
        }
        return result
    }

    private static func priceString(_ price: Double) -> String {
        price == floor(price) ? String(format: "%.0f", price) : String(format: "%.2f", price)
    }
}

struct SavedProjectDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var confirmingDeletion = false
    @State private var showingUnlock = false

    let projectID: SavedProject.ID

    var body: some View {
        Group {
            if let project {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        projectHeader(project)

                        NavigationLink {
                            ProjectChecklistView(projectID: project.id)
                        } label: {
                            Label("Open claim checklist", systemImage: "checklist")
                        }
                        .buttonStyle(OffsetPrimaryButtonStyle())

                        activePrograms(project)
                        relatedHistory(project)
                    }
                    .padding()
                    .padding(.bottom, 72)
                }
                .offsetScreen()
                .navigationTitle(project.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Edit project", systemImage: "pencil") { showingEditor = true }
                            Button("Delete project", systemImage: "trash", role: .destructive) { confirmingDeletion = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityIdentifier("saved-project.menu")
                    }
                }
                .sheet(isPresented: $showingEditor) {
                    SaveProjectEditorView(project: project) { appState.saveProject($0) }
                }
                .sheet(isPresented: $showingUnlock) {
                    PremiumUnlockView().environmentObject(subscriptions)
                }
                .confirmationDialog("Delete this project?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
                    Button("Delete project", role: .destructive) {
                        appState.deleteProject(id: project.id)
                        dismiss()
                    }
                } message: {
                    Text("Its saved checklist progress will also be deleted.")
                }
            } else {
                EmptyStateView(icon: "trash", title: "Project removed", message: "This saved project is no longer available.")
            }
        }
    }

    private var project: SavedProject? {
        appState.savedProjects.first { $0.id == projectID }
    }

    private var experience: ProjectExperienceService? {
        try? .bundled(profile: appState.profile)
    }

    private func projectHeader(_ project: SavedProject) -> some View {
        HStack(spacing: 16) {
            Image(systemName: project.projectType.icon)
                .font(.title)
                .foregroundStyle(OffsetTheme.emerald)
                .frame(width: 58, height: 58)
                .background(OffsetTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 4) {
                OffsetEyebrow(text: project.projectType.displayName)
                Text(project.stickerPriceUSD, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.title2.weight(.bold).monospacedDigit())
                Text("Sticker price")
                    .font(.caption)
                    .foregroundStyle(OffsetTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .offsetCard(elevated: true)
    }

    @ViewBuilder
    private func activePrograms(_ project: SavedProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            OffsetEyebrow(text: "Current matches")
            if let profile = appState.profile,
               let matches = experience?.matches(for: project, profile: profile),
               !matches.isEmpty {
                ForEach(matches) { match in
                    if subscriptions.hasPremiumAccess || match.program.level == .federal {
                        NavigationLink {
                            ProgramDetailView(program: match.program, estimatedSavingsUSD: match.estimatedSavingsUSD)
                        } label: {
                            ProgramSummaryRow(program: match.program, savingsUSD: match.estimatedSavingsUSD)
                        }
                        .buttonStyle(.plain)
                    } else {
                        LockedProgramCard(level: match.program.level) { showingUnlock = true }
                    }
                }
            } else {
                InlineMessageCard(
                    icon: "calendar.badge.exclamationmark",
                    title: "No active matches",
                    message: "The verified catalog has no currently active program for this project and profile. Related closed programs remain available below for reference."
                )
            }
        }
    }

    @ViewBuilder
    private func relatedHistory(_ project: SavedProject) -> some View {
        let relatedPrograms = experience?.relatedPrograms(for: project.projectType).filter {
            $0.status != .active && isRelevant($0, profile: appState.profile)
        } ?? []
        if !relatedPrograms.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                OffsetEyebrow(text: "Other programs")
                ForEach(relatedPrograms) { program in
                    if subscriptions.hasPremiumAccess || program.level == .federal {
                        NavigationLink {
                            ProgramDetailView(program: program)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(program.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(OffsetTheme.text)
                                    Text("\(program.status.displayName) · Verified \(program.lastVerifiedDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(OffsetTheme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(OffsetTheme.outline)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("program-history-row")
                        .offsetCard()
                    } else {
                        LockedProgramCard(level: program.level) { showingUnlock = true }
                    }
                }
            }
        }
    }

    private func isRelevant(_ program: Program, profile: UserProfile?) -> Bool {
        guard let profile else { return false }
        switch program.level {
        case .federal:
            return true
        case .state, .regional, .local:
            return program.eligibilityStates.contains(profile.state.uppercased())
        case .utility:
            guard let utility = profile.utilityProvider else { return false }
            return program.eligibilityUtilities.contains(utility)
        }
    }
}

struct ProgramDetailView: View {
    let program: Program
    var estimatedSavingsUSD: Double?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    OffsetEyebrow(text: "\(levelText) · \(benefitText)")
                    Text(program.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(OffsetTheme.text)
                    Text(program.description)
                        .foregroundStyle(OffsetTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 10) {
                    OffsetEyebrow(text: "AMOUNT")
                    Text(amountExplanation)
                        .font(.title3.weight(.semibold))
                    if let estimatedSavingsUSD {
                        LabeledContent("Estimated for your project") {
                            Text(estimatedSavingsUSD, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .fontWeight(.bold)
                                .foregroundStyle(OffsetTheme.emerald)
                        }
                    }
                    Text("Actual eligibility and value are determined by the program administrator.")
                        .font(.caption)
                        .foregroundStyle(OffsetTheme.secondaryText)
                }
                .offsetCard(elevated: true)

                detailSection(title: "ELIGIBILITY") {
                    ForEach(Array(program.eligibilitySummary.enumerated()), id: \.offset) { _, item in
                        BulletRow(text: item)
                    }
                }

                detailSection(title: "HOW TO CLAIM") {
                    ForEach(Array(program.claimSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(Color.white)
                                .frame(width: 25, height: 25)
                                .background(OffsetTheme.emerald, in: Circle())
                            Text(step)
                                .foregroundStyle(OffsetTheme.text)
                        }
                    }
                }

                detailSection(title: "PROGRAM RECORD") {
                    LabeledContent("Status", value: statusText)
                    LabeledContent("Deadline", value: deadlineText)
                    LabeledContent("Last verified", value: program.lastVerifiedDate.formatted(date: .long, time: .omitted))
                    if let url = URL(string: program.sourceURL) {
                        Link(destination: url) {
                            Label("Open official source", systemImage: "arrow.up.right.square")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 48)
        }
        .offsetScreen()
        .navigationTitle("Program details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            OffsetEyebrow(text: title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .offsetCard()
    }

    private var amountExplanation: String {
        switch program.amountType {
        case .percentage(let value):
            return "\(Self.percent(value))% of eligible project cost"
        case .fixedAmount(let value):
            return value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        case .upTo(let cap, let percentage):
            return "Up to \(cap.formatted(.currency(code: "USD").precision(.fractionLength(0)))) at \(Self.percent(percentage))% of eligible cost"
        case .range(let minimum, let maximum):
            if let minimum, let maximum {
                return "\(Self.money(minimum))–\(Self.money(maximum)), depending on eligibility and project details"
            }
            if let maximum { return "Up to \(Self.money(maximum)), subject to program rules" }
            if let minimum { return "Starting at \(Self.money(minimum)), subject to program rules" }
            return "Amount depends on eligibility and project details"
        case .formula(let explanation), .taxBenefit(let explanation), .nonCash(let explanation):
            return explanation
        case .unknown:
            return "Current amount requires confirmation from the program administrator"
        }
    }

    private static func percent(_ value: Double) -> String {
        (value > 1 ? value : value * 100).formatted(.number.precision(.fractionLength(0)))
    }

    private static func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private var statusText: String {
        switch program.status {
        case .active: "Active"
        case .dynamic: "Active — verify details"
        case .waitlist: "Waitlist"
        case .discovery: "Coverage in progress"
        case .paused: "Paused"
        case .closed: "Closed"
        }
    }

    private var levelText: String {
        switch program.level {
        case .federal: "Federal"
        case .state: "State"
        case .utility: "Utility"
        case .regional: "Regional"
        case .local: "Local"
        }
    }

    private var benefitText: String {
        switch program.benefitType {
        case .rebate: "Rebate"
        case .pointOfSaleDiscount: "Point-of-sale discount"
        case .nonrefundableTaxCredit: "Nonrefundable tax credit"
        case .refundableTaxCredit: "Refundable tax credit"
        case .salesTaxExemption: "Sales-tax exemption"
        case .propertyTaxExclusion: "Property-tax exclusion"
        case .nonCash: "No-cost service"
        }
    }

    private var deadlineText: String {
        program.deadline?.formatted(date: .long, time: .omitted) ?? "No published deadline"
    }
}

struct ChecklistRootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptions: SubscriptionService
    @State private var showingUnlock = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    OffsetEyebrow(text: "Your checklist")
                    Text("Track every claim step")
                        .font(.title.weight(.bold))
                    Text("Follow each program’s steps in order. Your progress is saved on this iPhone.")
                        .foregroundStyle(OffsetTheme.secondaryText)
                }

                if appState.savedProjects.isEmpty {
                    InlineMessageCard(icon: "bookmark", title: "No saved projects", message: "Calculate and save a project to create its claim checklist.")
                    Button("Go to project pricer") { appState.selectedTab = .projects }
                        .buttonStyle(OffsetPrimaryButtonStyle())
                } else if let profile = appState.profile, let experience {
                    ForEach(appState.savedProjects) { project in
                        ProjectChecklistCard(
                            project: project,
                            groups: experience.checklistGroups(for: project, profile: profile),
                            hasPremiumAccess: subscriptions.hasPremiumAccess,
                            unlock: { showingUnlock = true }
                        )
                    }
                } else {
                    InlineMessageCard(icon: "exclamationmark.triangle", title: "Checklist unavailable", message: "Offset couldn’t load the verified program catalog. Your saved projects and completed steps are still safe on this device.")
                }
            }
            .padding()
            .padding(.bottom, 72)
        }
        .offsetScreen()
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingUnlock) {
            PremiumUnlockView().environmentObject(subscriptions)
        }
    }

    private var experience: ProjectExperienceService? {
        try? .bundled(profile: appState.profile)
    }
}

struct ProjectChecklistView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptions: SubscriptionService
    @State private var showingUnlock = false
    let projectID: SavedProject.ID

    var body: some View {
        ScrollView {
            if let project,
               let profile = appState.profile,
               let experience = try? ProjectExperienceService.bundled(profile: profile) {
                ProjectChecklistCard(
                    project: project,
                    groups: experience.checklistGroups(for: project, profile: profile),
                    hasPremiumAccess: subscriptions.hasPremiumAccess,
                    unlock: { showingUnlock = true }
                )
                .padding()
            } else {
                InlineMessageCard(icon: "exclamationmark.triangle", title: "Checklist unavailable", message: "This project or the verified catalog could not be loaded.")
                    .padding()
            }
        }
        .offsetScreen()
        .navigationTitle("Claim checklist")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingUnlock) {
            PremiumUnlockView().environmentObject(subscriptions)
        }
    }

    private var project: SavedProject? {
        appState.savedProjects.first { $0.id == projectID }
    }
}

private struct ProjectChecklistCard: View {
    @EnvironmentObject private var appState: AppState
    let project: SavedProject
    let groups: [ProjectExperienceService.ChecklistGroup]
    let hasPremiumAccess: Bool
    let unlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: project.projectType.icon)
                    .foregroundStyle(OffsetTheme.emerald)
                    .frame(width: 38, height: 38)
                    .background(OffsetTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name).font(.headline)
                    Text(progressText)
                        .font(.caption)
                        .foregroundStyle(OffsetTheme.secondaryText)
                }
            }

            if groups.isEmpty {
                Text("No active claim steps are available for this project right now.")
                    .font(.subheadline)
                    .foregroundStyle(OffsetTheme.secondaryText)
            } else {
                ForEach(Array(groups.enumerated()), id: \.element.id) { groupIndex, group in
                    if hasPremiumAccess || group.program.level == .federal {
                        VStack(alignment: .leading, spacing: 10) {
                            NavigationLink {
                                ProgramDetailView(program: group.program, estimatedSavingsUSD: group.match.estimatedSavingsUSD)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(groupIndex + 1). \(group.program.name)")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(OffsetTheme.text)
                                        Text(levelName(group.program.level))
                                            .font(.caption)
                                            .foregroundStyle(OffsetTheme.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "info.circle")
                                }
                            }
                            .buttonStyle(.plain)

                            ForEach(Array(group.steps.enumerated()), id: \.offset) { stepIndex, step in
                                ChecklistStepRow(
                                    title: step,
                                    isComplete: appState.isClaimStepComplete(stepID(programID: group.program.id, index: stepIndex))
                                ) {
                                    let id = stepID(programID: group.program.id, index: stepIndex)
                                    appState.setClaimStep(id, isComplete: !appState.isClaimStepComplete(id))
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("\(levelName(group.program.level)) checklist details", systemImage: "lock.fill")
                                .font(.subheadline.weight(.semibold))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(OffsetTheme.outline.opacity(0.3))
                                .frame(height: 11)
                                .blur(radius: 2)
                            Button("Unlock checklist details", action: unlock)
                                .buttonStyle(OffsetSecondaryButtonStyle())
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Locked \(levelName(group.program.level).lowercased()) checklist details")
                        .accessibilityHint("Unlock full savings to view these claim steps")
                    }

                    if groupIndex < groups.count - 1 { Divider() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .offsetCard(padding: 18, elevated: true)
    }

    private var visibleGroups: [ProjectExperienceService.ChecklistGroup] {
        groups.filter { hasPremiumAccess || $0.program.level == .federal }
    }

    private var progressText: String {
        let ids = visibleGroups.flatMap { group in
            group.steps.indices.map { stepID(programID: group.program.id, index: $0) }
        }
        let completed = ids.filter(appState.isClaimStepComplete).count
        return ids.isEmpty ? "No active steps" : "\(completed) of \(ids.count) visible steps complete"
    }

    private func stepID(programID: String, index: Int) -> ClaimStepID {
        ClaimStepID(projectID: project.id, programID: programID, stepIndex: index)
    }

    private func levelName(_ level: ProgramLevel) -> String {
        switch level {
        case .federal: "Federal"
        case .state: "State"
        case .utility: "Utility"
        case .regional: "Regional"
        case .local: "Local"
        }
    }
}

private struct ChecklistStepRow: View {
    let title: String
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isComplete ? OffsetTheme.emerald : OffsetTheme.outline)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isComplete ? OffsetTheme.secondaryText : OffsetTheme.text)
                    .strikethrough(isComplete)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isComplete ? "Complete" : "Not complete")
        .accessibilityHint("Double tap to mark \(isComplete ? "not complete" : "complete")")
    }
}

private struct ProgramSummaryRow: View {
    let program: Program
    let savingsUSD: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(OffsetTheme.emerald)
            VStack(alignment: .leading, spacing: 3) {
                Text(program.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OffsetTheme.text)
                Text(savingsUSD, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(OffsetTheme.emerald)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(OffsetTheme.outline)
        }
        .contentShape(Rectangle())
        .offsetCard()
    }
}

private struct LockedProgramCard: View {
    let level: ProgramLevel
    let unlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Locked \(levelName.lowercased()) match", systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
            RoundedRectangle(cornerRadius: 4)
                .fill(OffsetTheme.outline.opacity(0.3))
                .frame(height: 11)
                .blur(radius: 2)
            Button("Unlock full savings", action: unlock)
                .buttonStyle(OffsetSecondaryButtonStyle())
        }
        .offsetCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Locked \(levelName.lowercased()) incentive match")
        .accessibilityHint("Unlock full savings to reveal the program")
    }

    private var levelName: String {
        switch level {
        case .federal: "Federal"
        case .state: "State"
        case .utility: "Utility"
        case .regional: "Regional"
        case .local: "Local"
        }
    }
}

private struct BulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(OffsetTheme.emerald)
            Text(text)
                .foregroundStyle(OffsetTheme.text)
        }
    }
}

struct InlineMessageCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(OffsetTheme.emerald)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(OffsetTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .offsetCard(padding: 20)
    }
}
