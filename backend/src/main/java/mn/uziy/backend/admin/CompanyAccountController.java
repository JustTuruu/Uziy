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

/** HTTP adapter: the admin opens and lists company accounts ({@code POST} answers 201, a taken phone 409). */
@RestController
@RequestMapping("/admin/companies")
@PreAuthorize("hasRole('ADMIN')")
public class CompanyAccountController {

    private final CompanyAccountService companies;

    public CompanyAccountController(CompanyAccountService companies) {
        this.companies = companies;
    }

    @PostMapping
    public ResponseEntity<CompanyAccountDto> create(@Valid @RequestBody CreateCompanyReq body,
                                                    @Auth JwtPrincipal principal) {
        return ResponseEntity.status(HttpStatus.CREATED).body(companies.create(body, principal.userId()));
    }

    @GetMapping
    public List<CompanyAccountDto> list(@Auth JwtPrincipal principal) {
        return companies.list(principal.userId());
    }
}
