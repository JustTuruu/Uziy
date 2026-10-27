package mn.uziy.backend.security;

import org.springframework.test.context.TestPropertySource;

/**
 * The API with the console phone check turned on ({@code uziy.console-login.phone-check=true}), as production may
 * run it: admins and companies on an unknown browser must also text a code from the account's phone. Every subclass
 * shares this one Spring context.
 */
@TestPropertySource(properties = "uziy.console-login.phone-check=true")
public abstract class AbstractPhoneCheckedConsoleLoginIntegrationTest extends AbstractApiIntegrationTest {
}
