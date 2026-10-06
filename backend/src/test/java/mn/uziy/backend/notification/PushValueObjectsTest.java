package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class PushValueObjectsTest {

    @Test
    void pushMessageDefensivelyCopiesItsData() {
        Map<String, String> data = new HashMap<>(Map.of("k", "v"));
        PushMessage m = new PushMessage("t", "b", data);
        data.put("x", "y");

        assertThat(m.data()).containsOnlyKeys("k");
        assertThatThrownBy(() -> m.data().put("a", "b")).isInstanceOf(UnsupportedOperationException.class);
    }

    @Test
    void pushResultIsImmutableAndNoneIsEmpty() {
        List<String> tokens = new ArrayList<>(List.of("a"));
        PushResult r = new PushResult(tokens);
        tokens.add("b");

        assertThat(r.invalidTokens()).containsExactly("a");
        assertThat(PushResult.none().invalidTokens()).isEmpty();
    }
}
