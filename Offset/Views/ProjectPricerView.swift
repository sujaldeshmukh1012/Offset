import SwiftUI
import UIKit
import RevenueCat

struct ProjectPricerView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel = ProjectPricerViewModel()
    @FocusState private var focusedField: String?
    @State private var showingUnlock = false
    @State private var showingSaveProject = false
    @State private var showingNotificationPrimer = false
    @State private var revealStage = 3
    @State private var eligibilityQuestions: [EligibilityQuestion] = []
    @State private var coverageAssessment: CoverageAssessment?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                intro
                projectPicker
                coverageCard
                eligibilitySection
                priceEntry
                calculateButton
                stateContent
                if canSaveCurrentProject {
                    saveCurrentProjectButton
                }
                SavedProjectsSection()
            }
            .padding()
            .padding(.bottom, 72)
        }
        .offsetScreen()
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                    viewModel.formatPriceForEditingEnd()
                }
            }
        }
        .onAppear {
            if viewModel.selectedProject == nil {
                viewModel.selectedProject = appState.profile?.selectedProjects.first
            }
            refreshEligibilityQuestions()
        }
        .onChange(of: viewModel.selectedProject) { _ in
            viewModel.invalidateResults()
            refreshEligibilityQuestions()
        }
        .onChange(of: subscriptions.hasPremiumAccess) { _ in
            guard viewModel.status == .results else { return }
            viewModel.calculate(profile: appState.profile, hasPremiumAccess: subscriptions.hasPremiumAccess)
        }
        .task(id: viewModel.calculationID) {
            guard viewModel.status == .results else { return }
            await revealResults()
        }
        .sheet(isPresented: $showingUnlock) {
            PremiumUnlockView()
                .environmentObject(subscriptions)
        }
        .sheet(isPresented: $showingSaveProject) {
            if let selectedProject = viewModel.selectedProject {
                SaveProjectEditorView(
                    defaultProjectType: selectedProject,
                    defaultPriceUSD: viewModel.stickerPriceUSD
                ) { project in
                    appState.createProject(project, hasPremiumAccess: subscriptions.hasPremiumAccess)
                }
            }
        }
        .sheet(isPresented: $showingNotificationPrimer) {
            NotificationValuePrimerView {
                showingNotificationPrimer = false
            }
                .environmentObject(appState)
                .environmentObject(notifications)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            OffsetEyebrow(text: "Project estimate")
            Text("Estimate your project cost")
                .font(.title.weight(.bold))
                .foregroundStyle(OffsetTheme.text)
            Text("Choose an upgrade and enter the quoted price. We’ll apply programs currently available in your area.")
                .foregroundStyle(OffsetTheme.secondaryText)
        }
    }

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            OffsetEyebrow(text: "Choose a project")
            LazyVGrid(columns: projectColumns, spacing: 10) {
                ForEach(orderedProjects) { project in
                    Button {
                        viewModel.selectedProject = project
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: project.icon)
                            Text(project.displayName)
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                            if viewModel.selectedProject == project {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.selectedProject == project ? OffsetTheme.emerald : OffsetTheme.text)
                    .background(
                        viewModel.selectedProject == project ? OffsetTheme.surfaceHigh : OffsetTheme.surface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                viewModel.selectedProject == project ? OffsetTheme.emerald : OffsetTheme.outline,
                                lineWidth: viewModel.selectedProject == project ? 2 : 1
                            )
                    }
                    .accessibilityLabel(project.displayName)
                    .accessibilityValue(viewModel.selectedProject == project ? "Selected" : "Not selected")
                }
            }
        }
    }

    private var orderedProjects: [ProjectType] {
        let preferred = appState.profile?.selectedProjects ?? []
        return preferred + ProjectType.allCases.filter { !preferred.contains($0) }
    }

    private var projectColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 145), spacing: 10)]
    }

    @ViewBuilder
    private var coverageCard: some View {
        if let coverageAssessment {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: coverageIcon(coverageAssessment.confidence))
                    .font(.headline)
                    .foregroundStyle(coverageColor(coverageAssessment.confidence))
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(coverageAssessment.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OffsetTheme.text)
                    Text(coverageAssessment.message)
                        .font(.caption)
                        .foregroundStyle(OffsetTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offsetCard()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pricer.coverage")
        }
    }

    @ViewBuilder
    private var eligibilitySection: some View {
        if !eligibilityQuestions.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        OffsetEyebrow(text: "Eligibility details")
                        Text("Improve your match")
                            .font(.headline)
                            .foregroundStyle(OffsetTheme.text)
                    }
                    Spacer()
                    Text("\(answeredQuestionCount)/\(eligibilityQuestions.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OffsetTheme.secondaryText)
                }

                Text("Answer what you know. Unanswered items stay out of exact savings instead of being guessed.")
                    .font(.subheadline)
                    .foregroundStyle(OffsetTheme.secondaryText)

                ForEach(eligibilityQuestions) { question in
                    EligibilityQuestionRow(
                        question: question,
                        answer: answer(for: question.id),
                        focusedField: $focusedField,
                        update: { updateAnswer($0, field: question.id) }
                    )
                    if question.id != eligibilityQuestions.last?.id { Divider() }
                }
            }
            .offsetCard()
            .accessibilityIdentifier("pricer.eligibility")
        }
    }

    private var answeredQuestionCount: Int {
        eligibilityQuestions.filter { answer(for: $0.id) != nil }.count
    }

    private func answer(for field: String) -> EligibilityAnswer? {
        appState.profile.flatMap { EligibilityQuestionService.answer(for: field, in: $0) }
    }

    private func updateAnswer(_ answer: EligibilityAnswer?, field: String) {
        appState.setEligibilityAnswer(answer, for: field)
        viewModel.invalidateResults()
        refreshEligibilityQuestions()
    }

    private func refreshEligibilityQuestions() {
        guard let project = viewModel.selectedProject, let profile = appState.profile else {
            eligibilityQuestions = []
            coverageAssessment = nil
            return
        }
        eligibilityQuestions = EligibilityQuestionService.bundledQuestions(for: project, profile: profile)
        coverageAssessment = CoverageService.bundledAssessment(for: project, profile: profile)
    }

    private func coverageIcon(_ confidence: CoverageAssessment.Confidence) -> String {
        switch confidence {
        case .verified: "checkmark.shield.fill"
        case .verifiedDynamic: "clock.badge.checkmark"
        case .partial: "circle.lefthalf.filled"
        case .discovery: "magnifyingglass"
        case .unsupported: "questionmark.circle"
        }
    }

    private func coverageColor(_ confidence: CoverageAssessment.Confidence) -> Color {
        switch confidence {
        case .verified: OffsetTheme.emerald
        case .verifiedDynamic, .partial: OffsetTheme.navy
        case .discovery, .unsupported: OffsetTheme.secondaryText
        }
    }

    private var priceEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            OffsetEyebrow(text: "Quoted price")
            HStack(spacing: 4) {
                Text("$")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(OffsetTheme.secondaryText)
                TextField("0", text: Binding(
                    get: { viewModel.priceText },
                    set: viewModel.setPriceText
                ))
                .font(.title2.weight(.semibold))
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: "price")
                .submitLabel(.done)
                .accessibilityIdentifier("pricer.price")
            }
            .padding()
            .background(OffsetTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(invalidPriceMessage == nil ? OffsetTheme.outline.opacity(0.25) : OffsetTheme.error, lineWidth: 1)
            }
            if let invalidPriceMessage {
                Text(invalidPriceMessage)
                    .font(.footnote)
                    .foregroundStyle(OffsetTheme.error)
                    .accessibilityIdentifier("pricer.price-error")
            }
        }
    }

    private var calculateButton: some View {
        Button {
            focusedField = nil
            viewModel.formatPriceForEditingEnd()
            viewModel.calculate(profile: appState.profile, hasPremiumAccess: subscriptions.hasPremiumAccess)
            if viewModel.status == .results, let projectType = viewModel.selectedProject {
                appState.recordPricerDraft(projectType: projectType, stickerPriceUSD: viewModel.stickerPriceUSD)
                if !appState.notificationPreferences.hasPresentedValuePrimer {
                    appState.markNotificationValuePrimerPresented()
                    showingNotificationPrimer = true
                }
            }
        } label: {
            Label("Calculate my price", systemImage: "arrow.down.right")
        }
        .buttonStyle(OffsetPrimaryButtonStyle())
        .accessibilityIdentifier("pricer.calculate")
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.status {
        case .idle, .invalidPrice:
            EmptyView()
        case .results:
            VStack(spacing: 18) {
                resultCard
                programsToVerify
            }
        case .noMatches:
            VStack(spacing: 18) {
                messageCard(
                    icon: "magnifyingglass",
                    title: "No exact estimate yet",
                    message: noMatchMessage
                )
                programsToVerify
            }
            .accessibilityIdentifier("pricer.no-matches")
        case .incompleteProfile(let message):
            VStack(spacing: 14) {
                messageCard(icon: "person.crop.circle.badge.exclamationmark", title: "Complete your profile", message: message)
                Button("Edit profile") { appState.selectedTab = .settings }
                    .buttonStyle(OffsetSecondaryButtonStyle())
            }
        case .dataFailure(let message):
            VStack(spacing: 14) {
                messageCard(icon: "exclamationmark.triangle", title: "Incentive data unavailable", message: message)
                Button("Try loading again") { viewModel.reloadPrograms() }
                    .buttonStyle(OffsetSecondaryButtonStyle())
            }
            .accessibilityIdentifier("pricer.data-error")
        }
    }

    private var invalidPriceMessage: String? {
        if case .invalidPrice(let message) = viewModel.status { return message }
        return nil
    }

    private var noMatchMessage: String {
        let project = viewModel.selectedProject?.displayName.lowercased() ?? "project"
        let location = appState.profile.flatMap { $0.state.isEmpty ? nil : " in \($0.state)" } ?? ""
        return "Offset doesn’t have enough verified inputs to put an exact \(project) incentive\(location) into your total. Programs that need equipment, income, contractor, or live-funding confirmation appear below."
    }

    @ViewBuilder
    private var programsToVerify: some View {
        let programs = advisoryPrograms
        if !programs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                OffsetEyebrow(text: "Check before you buy")
                Text("Programs that may apply")
                    .font(.headline)
                    .foregroundStyle(OffsetTheme.text)
                Text("These are not included in the net price because the supplied data requires more project details or a live availability check.")
                    .font(.subheadline)
                    .foregroundStyle(OffsetTheme.secondaryText)

                ForEach(programs) { program in
                    if subscriptions.hasPremiumAccess || program.level == .federal {
                        NavigationLink {
                            ProgramDetailView(program: program)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.shield")
                                    .foregroundStyle(OffsetTheme.navy)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(program.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(OffsetTheme.text)
                                    Text(program.status.displayName)
                                        .font(.caption)
                                        .foregroundStyle(OffsetTheme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(OffsetTheme.outline)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { showingUnlock = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                Text("Additional \(program.level.displayName.lowercased()) program")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("Verify")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(OffsetTheme.secondaryText)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Unlock full program eligibility and source details")
                    }
                    if program.id != programs.last?.id { Divider() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offsetCard()
        }
    }

    private var advisoryPrograms: [Program] {
        guard let project = viewModel.selectedProject,
              let profile = appState.profile,
              let programs = try? ProgramStore.loadBundledPrograms(profile: profile) else { return [] }
        return programs.filter { program in
            guard program.projectTypes.contains(project), program.status != .active, program.status != .closed else { return false }
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

    private var canSaveCurrentProject: Bool {
        guard viewModel.selectedProject != nil, viewModel.stickerPriceUSD > 0 else { return false }
        return viewModel.status == .results || viewModel.status == .noMatches
    }

    private var saveCurrentProjectButton: some View {
        Button {
            if appState.canCreateProject(hasPremiumAccess: subscriptions.hasPremiumAccess) {
                showingSaveProject = true
            } else {
                showingUnlock = true
            }
        } label: {
            Label(
                appState.canCreateProject(hasPremiumAccess: subscriptions.hasPremiumAccess)
                    ? "Save this project"
                    : "Unlock to save another project",
                systemImage: appState.canCreateProject(hasPremiumAccess: subscriptions.hasPremiumAccess)
                    ? "bookmark.fill"
                    : "lock.fill"
            )
        }
        .buttonStyle(OffsetSecondaryButtonStyle())
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("pricer.save-project")
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Your estimate")
                    .font(.headline)
                    .foregroundStyle(OffsetTheme.text)
                Spacer()
                Label("Verified sources", systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OffsetTheme.navy)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(OffsetTheme.savingsTint, in: Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(subscriptions.hasPremiumAccess ? "Your estimated net price" : "Your visible price so far")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OffsetTheme.secondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(viewModel.stickerPriceUSD, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.title3)
                        .foregroundStyle(OffsetTheme.secondaryText)
                        .strikethrough(revealStage >= 3, color: OffsetTheme.secondaryText)
                    AnimatedCurrencyText(value: revealStage >= 3 ? viewModel.visibleNetPriceUSD : viewModel.stickerPriceUSD)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(OffsetTheme.emerald)
                        .contentTransition(.identity)
                }
            }
            .opacity(revealStage >= 1 ? 1 : 0)

            Divider()

            VStack(spacing: 0) {
                ForEach(viewModel.rows) { row in
                    switch row {
                    case .exact(let exact):
                        NavigationLink {
                            ProgramDetailView(program: exact.program, estimatedSavingsUSD: exact.savingsUSD)
                        } label: {
                            ExactIncentiveRow(row: exact)
                        }
                        .buttonStyle(.plain)
                        .opacity(revealStage >= 2 ? 1 : 0)
                    case .locked(_, let level):
                        LockedIncentiveRow(level: level)
                            .opacity(revealStage >= 2 ? 1 : 0)
                    }
                }
            }

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("How the total works")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.78))
                    Text("Sticker price − incentives in the order shown = estimated net price")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(OffsetTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                totalRow(
                    subscriptions.hasPremiumAccess ? "Total savings" : "Visible federal savings",
                    value: viewModel.visibleSavingsUSD,
                    highlighted: false
                )
                Divider().overlay(Color.white.opacity(0.18))
                totalRow(
                    subscriptions.hasPremiumAccess ? "Final net price" : "Visible price so far",
                    value: viewModel.visibleNetPriceUSD,
                    highlighted: true
                )
            }
            .padding(16)
            .foregroundStyle(Color.white)
            .background(OffsetTheme.navyDeep, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(revealStage >= 3 ? 1 : 0)

            if viewModel.hasLockedMatches {
                Button {
                    showingUnlock = true
                } label: {
                    Label("Unlock full savings", systemImage: "lock.open.fill")
                }
                .buttonStyle(OffsetPrimaryButtonStyle())
                .accessibilityHint("Shows subscription options without revealing locked savings")
                .accessibilityIdentifier("pricer.unlock")
                .opacity(revealStage >= 3 ? 1 : 0)
            }
        }
        .offsetCard(padding: 20, elevated: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Incentive price calculation")
        .accessibilityIdentifier("pricer.results")
    }

    private func totalRow(_ title: String, value: Double, highlighted: Bool) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    totalLabel(title)
                    totalValue(value, highlighted: highlighted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    totalLabel(title)
                    Spacer()
                    totalValue(value, highlighted: highlighted)
                }
            }
        }
    }

    private func totalLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.72))
    }

    private func totalValue(_ value: Double, highlighted: Bool) -> some View {
        Text(value, format: .currency(code: "USD").precision(.fractionLength(0)))
            .font(.system(size: highlighted ? 24 : 17, weight: .bold).monospacedDigit())
            .foregroundStyle(highlighted ? OffsetTheme.emeraldBright : Color.white)
    }

    private func messageCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(OffsetTheme.emerald)
                .accessibilityHidden(true)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(OffsetTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .offsetCard(padding: 22)
    }

    @MainActor
    private func revealResults() async {
        if reduceMotion {
            revealStage = 3
            return
        }
        revealStage = 0
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) { revealStage = 1 }
        try? await Task.sleep(nanoseconds: 240_000_000)
        guard !Task.isCancelled else { return }
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) { revealStage = 2 }
        try? await Task.sleep(nanoseconds: 380_000_000)
        guard !Task.isCancelled else { return }
        Haptics.impact(.medium)
        withAnimation(.spring(response: 0.62, dampingFraction: 0.8)) { revealStage = 3 }
    }
}

private struct EligibilityQuestionRow: View {
    let question: EligibilityQuestion
    let answer: EligibilityAnswer?
    let focusedField: FocusState<String?>.Binding
    let update: (EligibilityAnswer?) -> Void
    @State private var numberText: String

    init(
        question: EligibilityQuestion,
        answer: EligibilityAnswer?,
        focusedField: FocusState<String?>.Binding,
        update: @escaping (EligibilityAnswer?) -> Void
    ) {
        self.question = question
        self.answer = answer
        self.focusedField = focusedField
        self.update = update
        if case .number(let value) = answer {
            _numberText = State(initialValue: value.formatted(.number.precision(.fractionLength(0...2))))
        } else {
            _numberText = State(initialValue: "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OffsetTheme.text)
            Text(question.help)
                .font(.caption)
                .foregroundStyle(OffsetTheme.secondaryText)

            switch question.kind {
            case .boolean:
                HStack(spacing: 8) {
                    answerButton("Not sure", id: "unknown", selected: answer == nil) { update(nil) }
                    answerButton("Yes", id: "yes", selected: answer == .boolean(true)) { update(.boolean(true)) }
                    answerButton("No", id: "no", selected: answer == .boolean(false)) { update(.boolean(false)) }
                }
            case .choice(let choices):
                Picker("Answer", selection: choiceBinding) {
                    Text("Not sure").tag("")
                    ForEach(choices) { choice in Text(choice.label).tag(choice.value) }
                }
                .pickerStyle(.menu)
                .tint(OffsetTheme.navy)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("eligibility.\(question.id).choice")
            case .number(let suffix):
                HStack {
                    TextField("Not sure", text: $numberText)
                        .keyboardType(.decimalPad)
                        .focused(focusedField, equals: question.id)
                        .accessibilityIdentifier("eligibility.\(question.id).number")
                        .onChange(of: numberText) { value in
                            let sanitized = ProjectPricerViewModel.sanitizedCurrencyInput(value)
                            if sanitized != value { numberText = sanitized }
                            update(Double(sanitized).map(EligibilityAnswer.number))
                        }
                    Text(suffix)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OffsetTheme.secondaryText)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(OffsetTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eligibility.\(question.id)")
    }

    private var choiceBinding: Binding<String> {
        Binding(
            get: {
                guard case .text(let value) = answer else { return "" }
                return value
            },
            set: { update($0.isEmpty ? nil : .text($0)) }
        )
    }

    private func answerButton(
        _ title: String,
        id: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.caption.weight(.semibold))
            .foregroundStyle(selected ? Color.white : OffsetTheme.text)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(selected ? OffsetTheme.navy : OffsetTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 10))
            .buttonStyle(.plain)
            .accessibilityIdentifier("eligibility.\(question.id).\(id)")
    }
}

private struct ExactIncentiveRow: View {
    let row: ProjectPricerViewModel.ExactResultRow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: levelIcon)
                .foregroundStyle(OffsetTheme.emerald)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.programName)
                    .font(.subheadline.weight(.semibold))
                Text(row.level.displayName)
                    .font(.caption)
                    .foregroundStyle(OffsetTheme.secondaryText)
                Text("\(row.priceBeforeUSD.formatted(.currency(code: "USD").precision(.fractionLength(0)))) → \(row.priceAfterUSD.formatted(.currency(code: "USD").precision(.fractionLength(0))))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(OffsetTheme.secondaryText)
            }
            Spacer()
            Text("−\(row.savingsUSD.formatted(.currency(code: "USD").precision(.fractionLength(0))))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(OffsetTheme.emerald)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.programName), \(row.level.displayName), saves \(row.savingsUSD.formatted(.currency(code: "USD")))")
    }

    private var levelIcon: String {
        switch row.level {
        case .federal: "building.columns"
        case .state: "map"
        case .utility: "bolt"
        case .regional: "mappin.and.ellipse"
        case .local: "building.2"
        }
    }
}

private struct LockedIncentiveRow: View {
    let level: ProgramLevel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundStyle(OffsetTheme.secondaryText)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text("\(level.displayName) incentive match")
                    .font(.subheadline.weight(.semibold))
                RoundedRectangle(cornerRadius: 3)
                    .fill(OffsetTheme.outline.opacity(0.32))
                    .frame(width: 118, height: 8)
                    .blur(radius: 2)
                    .accessibilityHidden(true)
            }
            Spacer()
            Text("Locked")
                .font(.caption.weight(.semibold))
                .foregroundStyle(OffsetTheme.secondaryText)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Locked \(level.displayName.lowercased()) incentive match")
        .accessibilityHint("Unlock full savings to view its name and value")
    }
}

private struct AnimatedCurrencyText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(value, format: .currency(code: "USD").precision(.fractionLength(0)))
            .monospacedDigit()
    }
}

struct PremiumUnlockView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    private let configuration = AppConfiguration()
    @State private var showingPrivacy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        OffsetLogoMark(size: 50)
                        Text("Unlock your full savings")
                            .font(.title.weight(.bold))
                            .foregroundStyle(OffsetTheme.text)
                            .multilineTextAlignment(.center)
                        Text("Reveal matched state and utility incentives, their application order, and your complete estimated net price.")
                            .font(.subheadline)
                            .foregroundStyle(OffsetTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        premiumBenefit("Reveal every matched incentive", icon: "eye.fill")
                        premiumBenefit("See the complete application order", icon: "list.number")
                        premiumBenefit("Know your final estimated net price", icon: "dollarsign.circle")
                        premiumBenefit("Save and track unlimited projects", icon: "bookmark.fill")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offsetCard(padding: 18)

                    VStack(spacing: 12) {
                        ForEach(displayedPlanIDs, id: \.self) { id in
                            purchaseButton(
                                id: id,
                                fallback: id == configuration.revenueCatAnnualProductID ? "Annual" : "Monthly",
                                highlighted: id == configuration.revenueCatAnnualProductID,
                                showsBestValue: displayedPlanIDs.count > 1 && id == configuration.revenueCatAnnualProductID
                            )
                        }
                    }

                    if let statusMessage {
                        Label(statusMessage.text, systemImage: statusMessage.icon)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(statusMessage.isError ? OffsetTheme.error : OffsetTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("paywall.status")
                    }

                    Button("Restore purchases") {
                        Task { await subscriptions.restore() }
                    }
                    .buttonStyle(OffsetSecondaryButtonStyle())
                    .disabled(isBusy)
                    .accessibilityIdentifier("paywall.restore")

                    Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the current period ends. Any trial shown is available only when confirmed by the App Store purchase sheet.")
                        .font(.caption)
                        .foregroundStyle(OffsetTheme.secondaryText)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 20) {
                        if let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                            Link("Terms of Use", destination: termsURL)
                        }
                        Button("Privacy") { showingPrivacy = true }
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offsetScreen()
            .navigationTitle("Offset Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await subscriptions.refresh() }
            .onChange(of: subscriptions.hasPremiumAccess) { hasAccess in
                if hasAccess { dismiss() }
            }
            .sheet(isPresented: $showingPrivacy) { PremiumPrivacyView() }
        }
    }

    private func premiumBenefit(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(OffsetTheme.text)
    }

    @ViewBuilder
    private func purchaseButton(id: String, fallback: String, highlighted: Bool, showsBestValue: Bool) -> some View {
        Button {
            Task { await subscriptions.purchase(productID: id) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(fallback)
                            .font(.headline)
                        if showsBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.16), in: Capsule())
                        }
                    }
                    if let detail = offerDetail(id: id) {
                        Text(detail).font(.caption).opacity(0.82)
                    }
                }
                Spacer()
                Text(displayPrice(id: id))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(highlighted ? Color.white : OffsetTheme.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(
                highlighted ? OffsetTheme.emerald : OffsetTheme.surface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(highlighted ? OffsetTheme.emerald : OffsetTheme.outline, lineWidth: highlighted ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!subscriptions.canPurchase(productID: id) || isBusy)
        .opacity(subscriptions.canPurchase(productID: id) && !isBusy ? 1 : 0.45)
        .accessibilityIdentifier(
            id == configuration.revenueCatAnnualProductID ? "paywall.annual" : "paywall.monthly"
        )
    }

    private var displayedPlanIDs: [String] {
#if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("-use-live-store") {
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-annual-only") {
                return [configuration.revenueCatAnnualProductID]
            }
            return [configuration.revenueCatAnnualProductID, configuration.revenueCatMonthlyProductID]
        }
#endif
        return [configuration.revenueCatAnnualProductID, configuration.revenueCatMonthlyProductID]
            .filter { subscriptions.product(id: $0) != nil }
    }

    private func displayPrice(id: String) -> String {
        if let product = subscriptions.product(id: id) {
            return product.localizedPriceString
        }

#if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("-use-live-store") {
            return id == configuration.revenueCatAnnualProductID ? "$39.99" : "$4.99"
        }
#endif

        return "Price unavailable"
    }

    private func offerDetail(id: String) -> String? {
        guard let discount = subscriptions.product(id: id)?.introductoryDiscount else {
            if id == configuration.revenueCatAnnualProductID,
               let annual = subscriptions.product(id: configuration.revenueCatAnnualProductID),
               let monthly = subscriptions.product(id: configuration.revenueCatMonthlyProductID) {
                let annualPrice = NSDecimalNumber(decimal: annual.price).doubleValue
                let monthlyYear = NSDecimalNumber(decimal: monthly.price).doubleValue * 12
                let percent = monthlyYear > 0 ? Int(((monthlyYear - annualPrice) / monthlyYear * 100).rounded()) : 0
                return percent > 0 ? "Save \(percent)% compared with monthly" : "Billed annually"
            }
            return id == configuration.revenueCatAnnualProductID ? "Billed annually" : "Billed monthly"
        }
        if discount.paymentMode == .freeTrial {
            return "\(periodText(discount.subscriptionPeriod)) free for eligible new subscribers"
        }
        return "Introductory offer: \(discount.localizedPriceString) for \(periodText(discount.subscriptionPeriod))"
    }

    private func periodText(_ period: SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = "period"
        }
        return "\(period.value) \(unit)"
    }

    private var statusMessage: (text: String, icon: String, isError: Bool)? {
        switch subscriptions.state {
        case .idle: nil
        case .loadingProducts: ("Loading current App Store plans…", "arrow.triangle.2.circlepath", false)
        case .purchasing: ("Waiting for the App Store…", "hourglass", false)
        case .pending: ("Purchase pending approval. Premium will unlock automatically when Apple approves it.", "clock.badge.exclamationmark", false)
        case .succeeded: ("Purchase complete. Premium is unlocked.", "checkmark.circle.fill", false)
        case .restoring: ("Checking your Apple ID for purchases…", "arrow.clockwise", false)
        case .restored: ("Purchase restored. Premium is unlocked.", "checkmark.circle.fill", false)
        case .restoredNoPurchase: ("No active Premium purchase was found for this Apple ID.", "info.circle", false)
        case .cancelled: ("Purchase cancelled. You were not charged.", "xmark.circle", false)
        case .failed(let message): (message, "exclamationmark.triangle.fill", true)
        }
    }

    private var isBusy: Bool {
        switch subscriptions.state {
        case .loadingProducts, .purchasing, .restoring: true
        default: false
        }
    }
}

private struct PremiumPrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("On-device data") {
                    Text("Your profile, saved projects, and checklist completion are stored locally on this device. Offset does not require an account.")
                }
                Section("Purchases") {
                    Text("Apple processes payment. RevenueCat receives purchase and entitlement information needed to provide Premium access; Offset does not receive your payment-card details.")
                }
                Section("Notifications") {
                    Text("If you opt in, OneSignal receives a device subscription identifier and the tags needed to deliver relevant reminders. You can turn reminders off in Offset or iOS Settings.")
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private enum Haptics {
    @MainActor
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

private extension ProgramLevel {
    var displayName: String {
        switch self {
        case .federal: "Federal"
        case .state: "State"
        case .utility: "Utility"
        case .regional: "Regional"
        case .local: "Local"
        }
    }
}
