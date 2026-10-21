package mn.uziy.backend.viewer;

import jakarta.validation.Valid;
import mn.uziy.backend.auth.Me;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter: an older viewer account adds its овог + нэр once ({@code PUT /viewer/me/name}). */
@RestController
@RequestMapping("/viewer/me/name")
@PreAuthorize("hasRole('VIEWER')")
public class ViewerNameController {

    private final ViewerNameService names;

    public ViewerNameController(ViewerNameService names) {
        this.names = names;
    }

    @PutMapping
    public Me set(@Valid @RequestBody SetViewerNameReq body, @Auth JwtPrincipal principal) {
        return names.setNameOnce(principal.userId(), body.lastName(), body.firstName());
    }
}
