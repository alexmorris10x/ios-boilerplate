import SwiftUI

/// Sign up screen view
struct SignUpView: View {
    // MARK: - Environment

    @Environment(AuthService.self) private var authService
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel: AuthViewModel?
    @State private var agreedToTerms = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UIConstants.Spacing.xl) {
                    // Header
                    headerSection

                    // Form
                    if let viewModel {
                        formSection(viewModel)
                    }

                    // Terms
                    termsSection

                    // Sign up button
                    if let viewModel {
                        signUpButton(viewModel)
                    }

                    // Login link
                    loginSection
                }
                .padding(UIConstants.Padding.section)
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .loadingOverlay(viewModel?.isLoading ?? false)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = AuthViewModel(authService: authService)
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: UIConstants.Spacing.sm) {
            Image(systemName: "person.badge.plus.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            Text("Join Us")
                .font(AppTheme.Typography.title)

            Text("Create an account to get started")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .padding(.bottom, UIConstants.Spacing.lg)
    }

    private func formSection(_ viewModel: AuthViewModel) -> some View {
        VStack(spacing: UIConstants.Spacing.md) {
            FormTextField(
                label: "Name",
                text: Binding(
                    get: { viewModel.name },
                    set: { viewModel.name = $0 }
                ),
                placeholder: "Enter your name",
                icon: "person.fill",
                textContentType: .name,
                isRequired: true,
                validationMessage: viewModel.nameError
            )
            .onChange(of: viewModel.name) { _, _ in
                viewModel.validateName()
            }

            FormTextField(
                label: "Email",
                text: Binding(
                    get: { viewModel.email },
                    set: { viewModel.email = $0 }
                ),
                placeholder: "Enter your email",
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never,
                isRequired: true,
                validationMessage: viewModel.emailError
            )
            .onChange(of: viewModel.email) { _, _ in
                viewModel.validateEmail()
            }

            FormSecureField(
                label: "Password",
                text: Binding(
                    get: { viewModel.password },
                    set: { viewModel.password = $0 }
                ),
                placeholder: "Create a password",
                isRequired: true,
                validationMessage: viewModel.passwordError
            )
            .onChange(of: viewModel.password) { _, _ in
                viewModel.validatePassword()
            }

            FormSecureField(
                label: "Confirm Password",
                text: Binding(
                    get: { viewModel.confirmPassword },
                    set: { viewModel.confirmPassword = $0 }
                ),
                placeholder: "Confirm your password",
                isRequired: true,
                validationMessage: viewModel.confirmPasswordError
            )
            .onChange(of: viewModel.confirmPassword) { _, _ in
                viewModel.validateConfirmPassword()
            }

            // Password requirements
            passwordRequirements

            // Error message
            if let error = viewModel.generalError {
                ErrorBanner(message: error) {
                    viewModel.resetForm()
                }
            }
        }
    }

    private var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            Text("Password must contain:")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            Group {
                requirementRow("At least 8 characters", met: (viewModel?.password.count ?? 0) >= 8)
                requirementRow("One uppercase letter", met: viewModel?.password.range(of: "[A-Z]", options: .regularExpression) != nil)
                requirementRow("One lowercase letter", met: viewModel?.password.range(of: "[a-z]", options: .regularExpression) != nil)
                requirementRow("One number", met: viewModel?.password.range(of: "[0-9]", options: .regularExpression) != nil)
            }
        }
        .padding(UIConstants.Spacing.md)
        .background(AppTheme.Colors.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium))
    }

    private func requirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: UIConstants.Spacing.sm) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : AppTheme.Colors.tertiaryText)
                .font(.caption)

            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(met ? AppTheme.Colors.text : AppTheme.Colors.tertiaryText)
        }
    }

    private var termsSection: some View {
        Toggle(isOn: $agreedToTerms) {
            HStack(spacing: 0) {
                Text("I agree to the ")
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Button("Terms of Service") {
                    // TODO: Open terms
                }

                Text(" and ")
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Button("Privacy Policy") {
                    // TODO: Open privacy policy
                }
            }
            .font(AppTheme.Typography.caption)
        }
        .toggleStyle(.checkboxStyle)
    }

    private func signUpButton(_ viewModel: AuthViewModel) -> some View {
        PrimaryLoadingButton("Create Account") {
            if await viewModel.signUp() {
                dismiss()
            }
        }
        .disabled(!agreedToTerms || !viewModel.isSignUpFormValid)
    }

    private var loginSection: some View {
        HStack {
            Text("Already have an account?")
                .foregroundStyle(AppTheme.Colors.secondaryText)

            Button("Sign In") {
                dismiss()
                router.present(sheet: .login)
            }
            .fontWeight(.semibold)
        }
        .font(AppTheme.Typography.subheadline)
        .padding(.top, UIConstants.Spacing.md)
    }
}

// MARK: - Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.sm) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isOn ? .accentColor : AppTheme.Colors.secondaryText)
                .onTapGesture {
                    configuration.isOn.toggle()
                }

            configuration.label
        }
    }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkboxStyle: CheckboxToggleStyle { CheckboxToggleStyle() }
}

// MARK: - Preview

#Preview {
    SignUpView()
        .environment(AuthService(apiClient: APIClient()))
        .environment(Router.shared)
}
