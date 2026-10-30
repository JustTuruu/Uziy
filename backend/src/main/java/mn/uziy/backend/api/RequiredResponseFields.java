package mn.uziy.backend.api;

import io.swagger.v3.core.converter.AnnotatedType;
import io.swagger.v3.core.converter.ModelConverter;
import io.swagger.v3.core.converter.ModelConverterContext;
import io.swagger.v3.oas.models.media.Schema;
import java.lang.reflect.RecordComponent;
import java.lang.reflect.Type;
import java.util.Arrays;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * Describes response records the way Jackson writes them: every component is always in the JSON (nulls are
 * written, not left out), and one annotated {@code @Nullable} may be {@code null} — the backend's rule is that a
 * value which may be missing says so (CLAUDE.md §0.2). Without this every field of every response would be
 * optional in the generated TypeScript, and {@code null} would never appear in it. Request records
 * ({@code *Req} and the records nested in them) keep the bean-validation rule ({@code @NotNull}, {@code @NotBlank}): many of their fields have
 * server-side defaults.
 */
public class RequiredResponseFields implements ModelConverter {

    static final String REQUEST_SUFFIX = "Req";
    private static final String NULL_TYPE = "null";

    @Override
    @SuppressWarnings({"rawtypes", "unchecked"})
    public @Nullable Schema resolve(AnnotatedType type, ModelConverterContext context, Iterator<ModelConverter> chain) {
        Schema resolved = chain.hasNext() ? chain.next().resolve(type, context, chain) : null;
        Class<?> raw = rawClass(type.getType());
        if (resolved == null || raw == null || !raw.isRecord() || isRequest(raw)) {
            return resolved;
        }
        Schema model = resolved.get$ref() == null ? resolved : context.getDefinedModels().get(nameOf(resolved));
        if (model == null || model.getProperties() == null) {
            return resolved;
        }
        Map<String, Schema> properties = model.getProperties();
        List<String> nullable = nullableComponents(raw);
        for (RecordComponent component : raw.getRecordComponents()) {
            String name = component.getName();
            Schema property = properties.get(name);
            if (property == null) {
                continue;
            }
            if (model.getRequired() == null || !model.getRequired().contains(name)) {
                model.addRequiredItem(name);
            }
            if (nullable.contains(name)) {
                properties.put(name, orNull(property));
            }
        }
        return resolved;
    }

    /** A {@code *Req} record, or one nested in it ({@code CreateCampaignReq.NewQuestion}). */
    static boolean isRequest(Class<?> type) {
        for (Class<?> c = type; c != null; c = c.getEnclosingClass()) {
            if (c.getSimpleName().endsWith(REQUEST_SUFFIX)) {
                return true;
            }
        }
        return false;
    }

    /** The record components that may be {@code null}, in declaration order. */
    static List<String> nullableComponents(Class<?> record) {
        return Arrays.stream(record.getRecordComponents())
                .filter(RequiredResponseFields::isNullable)
                .map(RecordComponent::getName)
                .toList();
    }

    /** OpenAPI 3.1: a plain type gains "null"; a reference becomes "the referenced object or null". */
    @SuppressWarnings({"rawtypes", "unchecked"})
    private static Schema orNull(Schema property) {
        if (property.get$ref() != null) {
            return new Schema().oneOf(List.of(new Schema().$ref(property.get$ref()), new Schema().types(Set.of(NULL_TYPE))));
        }
        if (property.getTypes() != null) {
            property.addType(NULL_TYPE);
        }
        return property;
    }

    private static boolean isNullable(RecordComponent c) {
        return c.getAnnotatedType().isAnnotationPresent(Nullable.class)
                || c.isAnnotationPresent(Nullable.class)
                || Optional.class.equals(c.getType());
    }

    private static @Nullable Class<?> rawClass(Type type) {
        if (type instanceof Class<?> c) {
            return c;
        }
        if (type instanceof com.fasterxml.jackson.databind.JavaType javaType) {
            return javaType.getRawClass();
        }
        return null;
    }

    private static String nameOf(Schema<?> ref) {
        String r = ref.get$ref();
        return r.substring(r.lastIndexOf('/') + 1);
    }
}
