package mn.uziy.backend.admin;

import jakarta.validation.Valid;
import java.util.List;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter: an admin opens and lists admin accounts ({@code POST} answers 201, a taken phone 409). */
@RestController
@RequestMapping("/admin/admins")
@PreAuthorize("hasRole('ADMIN')")
public class AdminAccountController {

    private final AdminAccountService admins;

    public AdminAccountController(AdminAccountService admins) {
        this.admins = admins;
    }

    @PostMapping
    public ResponseEntity<AdminAccountDto> create(@Valid @RequestBody CreateAdminReq body,
                                                  @Auth JwtPrincipal principal) {
        return ResponseEntity.status(HttpStatus.CREATED).body(admins.create(body, principal.userId()));
    }

    @GetMapping
    public List<AdminAccountDto> list(@Auth JwtPrincipal principal) {
        return admins.list(principal.userId());
    }
}
