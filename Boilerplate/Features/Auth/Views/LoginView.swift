import SwiftUI

/// Login screen view
struct LoginView: View {
    // MARK: - Environment

    @Environment(AuthService.self) private var authService
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel: AuthViewModel?

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

                    // Divider
                    dividerSection

                    // Social login
                    socialLoginSection

                    // Sign up link
                    signUpSection
                }
                .padding(UIConstants.Padding.section)
            }
            .navigationTitle("Sign In")
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
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            Text("Welcome Back")
                .font(AppTheme.Typography.title)

            Text("Sign in to continue")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .padding(.bottom, UIConstants.Spacing.lg)
    }

    private func formSection(_ viewModel: AuthViewModel) -> some View {
        VStack(spacing: UIConstants.Spacing.md) {
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
                placeholder: "Enter your password",
                validationMessage: viewModel.passwordError
            )

            // Forgot password
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    // TODO: Navigate to forgot password
                }
                .font(AppTheme.Typography.subheadline)
            }

            // Error message
            if let error = viewModel.generalError {
                ErrorBanner(message: error) {
                    viewModel.resetForm()
                }
            }

            // Login button
            PrimaryLoadingButton("Sign In") {
                if await viewModel.login() {
                    dismiss()
                }
            }
            .padding(.top, UIConstants.Spacing.md)
        }
    }

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(AppTheme.Colors.separator)
                .frame(height: 1)

            Text("or")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .padding(.horizontal, UIConstants.Spacing.sm)

            Rectangle()
                .fill(AppTheme.Colors.separator)
                .frame(height: 1)
        }
        .padding(.vertical, UIConstants.Spacing.md)
    }

    private var socialLoginSection: some View {
        VStack(spacing: UIConstants.Spacing.md) {
            // Apple Sign In
            Button {
                // TODO: Implement Apple Sign In
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("Continue with Apple")
                }
            }
            .buttonStyle(.secondary)

            // Google Sign In
            Button {
                // TODO: Implement Google Sign In
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text("Continue with Google")
                }
            }
            .buttonStyle(.secondary)
        }
    }

    private var signUpSection: some View {
        HStack {
            Text("Don't have an account?")
                .foregroundStyle(AppTheme.Colors.secondaryText)

            Button("Sign Up") {
                dismiss()
                router.present(sheet: .signUp)
            }
            .fontWeight(.semibold)
        }
        .font(AppTheme.Typography.subheadline)
        .padding(.top, UIConstants.Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environment(AuthService(apiClient: APIClient()))
        .environment(Router.shared)
}
