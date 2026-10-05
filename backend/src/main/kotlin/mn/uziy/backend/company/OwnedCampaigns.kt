package mn.uziy.backend.company

import mn.uziy.backend.common.ForbiddenException
import mn.uziy.backend.common.NotFoundException
import mn.uziy.backend.domain.CampaignEntity
import mn.uziy.backend.domain.CampaignRepository

/** Loads a campaign and enforces that the caller is the company that owns it. */
internal fun CampaignRepository.owned(companyId: Long, campaignId: Long): CampaignEntity {
    val c = findById(campaignId).orElseThrow { NotFoundException() }
    if (c.companyId != companyId) throw ForbiddenException()
    return c
}
