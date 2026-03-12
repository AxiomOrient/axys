import androidx.compose.runtime.Composable

class LoginHostStore {
    var screenState = LoginScreenState()

    fun onEmailChanged(value: String) {
        screenState = screenState.copy(email = value)
    }

    fun onPasswordChanged(value: String) {
        screenState = screenState.copy(password = value)
    }

    fun submitLogin() {}
}

@Composable
fun LoginHostScreen(store: LoginHostStore = LoginHostStore()) {
    LoginScreen(
        state = store.screenState,
        actions = LoginScreenActions(
            onEmailChanged = { value -> store.onEmailChanged(value) },
            onPasswordChanged = { value -> store.onPasswordChanged(value) },
            onSubmitLogin = { store.submitLogin() }
        )
    )
}
