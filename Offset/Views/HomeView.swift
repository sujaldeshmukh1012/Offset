import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var supabaseCatalog: SupabaseCatalogService
    @StateObject private var viewModel = HomeViewModel()
    @State private var showingAllOpportunities = false
    @State private var showingUnlock = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OffsetTheme.sectionSpacing) {
                header
                summaryContent
                opportunitySection
                if !subscriptions.hasPremiumAccess { premiumCard }
                calculatorCard
                SavedProjectsSection()
            }
            .frame(maxWidth: 920)
            .padding(.horizontal, OffsetTheme.screenMargin)
            .padding(.top, 12)
            .padding(.bottom, 80)
            .frame(maxWidth: .infinity)
        }
        .offsetScreen()
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OffsetTheme.canvas, for: .navigationBar)
        .task { viewModel.refresh(profile: appState.profile) }
        .onChange(of: appState.profile) { viewModel.refresh(profile: $0) }
        .onChange(of: supabaseCatalog.revision) { _ in
            viewModel.refresh(profile: appState.profile, force: true)
        }
        .sheet(isPresented: $showingUnlock) {
            PremiumUnlockView().environmentObject(subscriptions)
        }
        .accessibilityIdentifier("home.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            OffsetBrandHeader(badgeText: nil)
            Text("Your Offset")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(OffsetTheme.navyDeep)
            if let profile = appState.profile {
                Text(profileLine(profile))
                    .font(.subheadline)
                    .foregroundStyle(OffsetTheme.secondaryText)
                    .accessibilityLabel(profileAccessibilityLine(profile))
            }
        }
    }

    @ViewBuilder
    private var summaryContent: some View {
        if let message = viewModel.snapshot.errorMessage {
            EmptyStateView(icon: "exclamationmark.triangle", title: "Opportunities unavailable", message: message)
        } else if viewModel.snapshot.opportunities.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No verified opportunities yet",
                message: emptyOpportunityMessage
            )
        } else {
            OpportunitySummaryCard(snapshot: viewModel.snapshot)
        }
    }

    @ViewBuilder
    private var opportunitySection: some View {
        if !viewModel.snapshot.opportunities.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                OffsetSectionHeader(
                    title: "Potential opportunities",
                    subtitle: "Explore programs before you have a quote."
                )

                LazyVGrid(columns: opportunityColumns, spacing: 16) {
                    ForEach(visibleOpportunities) { opportunity in
                        NavigationLink {
                            OpportunityExploreView(project: opportunity.project)
                        } label: {
                            OpportunityCard(opportunity: opportunity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.opportunity.\(opportunity.project.rawValue)")
                    }
                }

                if viewModel.snapshot.opportunities.count > 4 {
                    Button(showingAllOpportunities ? "Show recommended" : "See all opportunities") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingAllOpportunities.toggle()
                        }
                    }
                    .buttonStyle(OffsetSecondaryButtonStyle())
                }
            }
        }
    }

    private var premiumCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                OffsetLogoMark(size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Offset Premium")
                        .font(.title3.weight(.bold))
                    Text("Everything you need to plan with confidence.")
                        .font(.subheadline)
                        .foregroundStyle(OffsetTheme.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                premiumLine("Every matched incentive")
                premiumLine("Net cost and application order")
                premiumLine("Claim guidance and unlimited projects")
            }

            Button("Explore Premium") { showingUnlock = true }
                .buttonStyle(OffsetPrimaryButtonStyle())
                .accessibilityIdentifier("home.unlock")
        }
        .offsetCard(padding: 20, elevated: true)
    }

    private var calculatorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Calculate a project", systemImage: "function")
                .font(.title3.weight(.bold))
                .foregroundStyle(OffsetTheme.navyDeep)
            Text("Already have a quote? See what the project could cost after incentives.")
                .font(.subheadline)
                .foregroundStyle(OffsetTheme.secondaryText)
            NavigationLink {
                ProjectPricerView()
            } label: {
                Text("Calculate project")
            }
            .buttonStyle(OffsetSecondaryButtonStyle())
            .accessibilityIdentifier("home.calculate-project")
        }
        .offsetCard(padding: 20)
    }

    private func premiumLine(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(OffsetTheme.text)
    }

    private var visibleOpportunities: [DiscoveredOpportunity] {
        showingAllOpportunities
            ? viewModel.snapshot.opportunities
            : Array(viewModel.snapshot.opportunities.prefix(4))
    }

    private var opportunityColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 440), spacing: 16)]
    }

    private var emptyOpportunityMessage: String {
        guard let profile = appState.profile else { return "Finish your profile to begin discovery." }
        if profile.utilityProvider == nil {
            return "No verified matches were found from the current profile. Add your utility in Settings to improve local coverage."
        }
        return "Offset has not verified a matching program for this profile. This does not mean no incentives exist."
    }

    private func profileLine(_ profile: UserProfile) -> String {
        let zip = profile.zipCode.count >= 3 ? "\(profile.zipCode.prefix(3))XX" : profile.state
        let occupancy = profile.isHomeowner ? "Homeowner" : "Renter"
        let utility = profile.utilityProvider.map(utilityDisplayName)
        return (["Based on \(zip)", occupancy] + [utility].compactMap { $0 }).joined(separator: "  •  ")
    }

    private func profileAccessibilityLine(_ profile: UserProfile) -> String {
        let occupancy = profile.isHomeowner ? "Homeowner" : "Renter"
        return "Opportunities based on ZIP code ending in \(profile.zipCode.suffix(2)), \(occupancy)"
    }

    private func utilityDisplayName(_ identifier: String) -> String {
        (try? LocationService.current())?.utilityName(for: identifier) ?? identifier
    }
}

private struct OpportunitySummaryCard: View {
    let snapshot: OpportunityDiscoverySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(snapshot.totalProgramCount) potential \(snapshot.totalProgramCount == 1 ? "program" : "programs") found")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.white)
                Text("A curated view based on your current profile.")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.78))
            }

            HStack(spacing: 0) {
                countColumn("Federal", level: .federal)
                Divider().overlay(Color.white.opacity(0.2))
                countColumn("State", level: .state)
                Divider().overlay(Color.white.opacity(0.2))
                countColumn("Utility", level: .utility)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(OffsetTheme.navyDeep, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: OffsetTheme.navyDeep.opacity(0.16), radius: 20, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.summary")
    }

    private func countColumn(_ label: String, level: ProgramLevel) -> some View {
        VStack(spacing: 3) {
            Text("\(snapshot.programCountsByLevel[level, default: 0])")
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
    }
}

private struct OpportunityCard: View {
    let opportunity: DiscoveredOpportunity

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image(opportunity.project.imageAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 142)
                    .clipped()
                    .accessibilityHidden(true)
                LinearGradient(
                    colors: [.clear, OffsetTheme.navyDeep.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                Text(opportunity.project.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white)
                    .padding(15)
            }

            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("\(opportunity.programCount) potential \(opportunity.programCount == 1 ? "program" : "programs")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OffsetTheme.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(OffsetTheme.mutedText)
                }
                HStack(spacing: 6) {
                    ForEach(opportunity.sourceLevels, id: \.self) { ProgramSourceBadge(level: $0) }
                }
                Text("Explore available \(opportunity.project.displayName.lowercased()) incentives")
                    .font(.caption)
                    .foregroundStyle(OffsetTheme.secondaryText)
            }
            .padding(15)
        }
        .background(OffsetTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: OffsetTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OffsetTheme.cardRadius, style: .continuous)
                .stroke(OffsetTheme.outline.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: OffsetTheme.navyDeep.opacity(0.07), radius: 14, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(opportunity.project.displayName), \(opportunity.programCount) potential programs, sources: \(opportunity.sourceLevels.map(\.shortDisplayName).joined(separator: ", "))")
        .accessibilityHint("Opens opportunity details")
    }
}

struct OpportunityExploreView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var supabaseCatalog: SupabaseCatalogService
    @FocusState private var focusedField: String?
    @State private var opportunity: DiscoveredOpportunity?
    @State private var showingUnlock = false

    let project: ProjectType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OffsetTheme.sectionSpacing) {
                hero
                if let opportunity {
                    evidence(opportunity)
                    qualification(opportunity)
                    calculate(opportunity)
                } else {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No current match",
                        message: "This opportunity changed after your profile update. Explore another category from Home."
                    )
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, OffsetTheme.screenMargin)
            .padding(.bottom, 72)
            .frame(maxWidth: .infinity)
        }
        .offsetScreen()
        .navigationTitle(project.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .task { refresh() }
        .onChange(of: appState.profile) { _ in refresh() }
        .onChange(of: supabaseCatalog.revision) { _ in refresh() }
        .sheet(isPresented: $showingUnlock) {
            PremiumUnlockView().environmentObject(subscriptions)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image(project.imageAssetName)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .clipped()
                .accessibilityHidden(true)
            LinearGradient(colors: [.clear, OffsetTheme.navyDeep.opacity(0.86)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                Text(project.displayName)
                    .font(.title.bold())
                if let opportunity {
                    Text("\(opportunity.programCount) potential \(opportunity.programCount == 1 ? "program" : "programs") identified")
                        .font(.subheadline.weight(.medium))
                }
            }
            .foregroundStyle(Color.white)
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func evidence(_ opportunity: DiscoveredOpportunity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            OffsetSectionHeader(
                title: "What Offset found",
                subtitle: "Program evidence first—no project price required."
            )
            ForEach(Array(opportunity.programs.enumerated()), id: \.element.id) { index, program in
                programRow(program, index: index, opportunity: opportunity)
                if index < opportunity.programs.count - 1 { Divider().overlay(OffsetTheme.divider) }
            }
            CoverageBadge(assessment: opportunity.coverage)
            Text(opportunity.coverage.message)
                .font(.caption)
                .foregroundStyle(OffsetTheme.secondaryText)
        }
        .offsetCard(padding: 20)
    }

    private func programRow(_ program: Program, index: Int, opportunity: DiscoveredOpportunity) -> some View {
        let canReveal = subscriptions.hasPremiumAccess || program.level == .federal
        return HStack(spacing: 12) {
            Image(systemName: statusIcon(program, opportunity: opportunity))
                .foregroundStyle(OffsetTheme.emerald)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(canReveal ? program.name : "\(program.level.shortDisplayName) program")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OffsetTheme.text)
                Text(statusText(program, opportunity: opportunity))
                    .font(.caption)
                    .foregroundStyle(OffsetTheme.secondaryText)
            }
            Spacer()
            ProgramSourceBadge(level: program.level)
            if !canReveal {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(OffsetTheme.mutedText)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(canReveal
            ? "\(program.name), \(program.level.shortDisplayName), \(statusText(program, opportunity: opportunity))"
            : "\(program.level.shortDisplayName) program, details locked, \(statusText(program, opportunity: opportunity))")
    }

    @ViewBuilder
    private func qualification(_ opportunity: DiscoveredOpportunity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            OffsetSectionHeader(
                title: "Refine your match",
                subtitle: opportunity.questions.isEmpty ? "Your match is ready." : "Add what you know for a more precise result."
            )
            if !opportunity.questions.isEmpty {
                Text("\(opportunity.answeredQuestionCount) of \(opportunity.questions.count) details completed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OffsetTheme.secondaryText)
            }

            if opportunity.questions.isEmpty {
                Label("Profile details complete", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OffsetTheme.success)
            } else {
                ForEach(opportunity.questions) { question in
                    EligibilityQuestionRow(
                        question: question,
                        answer: answer(for: question.id),
                        focusedField: $focusedField,
                        update: { updateAnswer($0, field: question.id) }
                    )
                    if question.id != opportunity.questions.last?.id { Divider().overlay(OffsetTheme.divider) }
                }
            }
        }
        .offsetCard(padding: 20)
    }

    private func calculate(_ opportunity: DiscoveredOpportunity) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Calculate your benefit")
                .font(.title3.bold())
            Text(opportunity.hasExactProgram
                 ? "Have a quote? Add it now to calculate only the benefits Offset can resolve safely."
                 : "A quote can help check price-based rules. Programs without a safe formula will remain advisory.")
                .font(.subheadline)
                .foregroundStyle(OffsetTheme.secondaryText)
            NavigationLink {
                ProjectPricerView(selectedProject: project)
            } label: {
                Text("Calculate \(project.displayName.lowercased())")
            }
            .buttonStyle(OffsetPrimaryButtonStyle())

            if !subscriptions.hasPremiumAccess {
                Button("Unlock complete program details") { showingUnlock = true }
                    .buttonStyle(OffsetSecondaryButtonStyle())
            }
        }
        .offsetCard(padding: 20, elevated: true)
    }

    private func statusIcon(_ program: Program, opportunity: DiscoveredOpportunity) -> String {
        if program.status == .active && opportunity.remainingQuestionCount == 0 { return "checkmark.circle.fill" }
        if program.status == .active { return "questionmark.circle.fill" }
        return "clock.fill"
    }

    private func statusText(_ program: Program, opportunity: DiscoveredOpportunity) -> String {
        if program.status == .active && opportunity.remainingQuestionCount == 0 { return "Potentially eligible" }
        if program.status == .active { return "More details needed" }
        return program.status == .dynamic ? "Live details required" : "Available in your area"
    }

    private func answer(for field: String) -> EligibilityAnswer? {
        appState.profile.flatMap { EligibilityQuestionService.answer(for: field, in: $0) }
    }

    private func updateAnswer(_ answer: EligibilityAnswer?, field: String) {
        appState.setEligibilityAnswer(answer, for: field)
        refresh()
    }

    private func refresh() {
        guard let profile = appState.profile else {
            opportunity = nil
            return
        }
        opportunity = OpportunityDiscoveryService.currentSnapshot(for: profile)
            .opportunities.first { $0.project == project }
    }
}

extension ProjectType {
    var imageAssetName: String {
        switch self {
        case .heatPump, .waterHeater: "OpportunityHeatPump"
        case .evPurchase, .evCharger: "OpportunityEV"
        case .solar, .batteryStorage: "OpportunitySolar"
        case .insulation, .ductwork, .weatherization: "OpportunityWeatherization"
        case .windows: "OpportunityWindows"
        }
    }
}
