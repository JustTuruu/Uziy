/// Rules for the guest / signed-in split: which pages need an account, where
/// a guest is sent to sign in, and where a fresh sign-in leads back to.
///
/// Pure (no BuildContext, no router import) except [finishAuth], so the
/// rules are unit-testable on their own.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/campaign.dart';
import '../services/viewer_service.dart';
import 'app_router.dart';
import 'router_push_target.dart';

/// Query parameter carrying the page to open after signing in.
const String kNextParam = 'next';

const String kCampaignGoneMessage = 'Энэ видео танд одоогоор байхгүй байна';

/// Pages a guest cannot open: the wallet and the profile (and everything
/// under them, e.g. the payout form and the profile menu pages).
bool requiresAccount(String location) =>
    location.startsWith(Routes.wallet) || location.startsWith(Routes.profile);

/// [route] with [next] attached as `?next=…` (nothing when [next] is null).
String authLocation(String route, {String? next}) => Uri(
      path: route,
      queryParameters: next == null ? null : {kNextParam: next},
    ).toString();

/// Router redirect: a guest asking for an account-only page goes to login and
/// comes back to that page afterwards; everyone else is left alone.
String? guestRedirect({required String location, required bool signedIn}) {
  if (signedIn || !requiresAccount(location)) return null;
  return authLocation(Routes.login, next: location);
}

/// Where a finished sign-in / registration leads.
sealed class PostAuthTarget {
  const PostAuthTarget();
}

class GoHomeTarget extends PostAuthTarget {
  const GoHomeTarget();
}

/// An account-only page the guest wanted (wallet, profile…).
class GoLocationTarget extends PostAuthTarget {
  const GoLocationTarget(this.location);
  final String location;
}

/// The video or survey the guest tapped.
class OpenCampaignTarget extends PostAuthTarget {
  const OpenCampaignTarget({required this.campaignId, required this.hasVideo});
  final int campaignId;
  final bool hasVideo;
}

/// Reads the `next` value. Anything that is not a known in-app destination
/// (a foreign URL, garbage, nothing) falls back to Home, so a crafted link
/// can never send a freshly signed-in user elsewhere.
PostAuthTarget parsePostAuth(String? next) {
  if (next == null || !next.startsWith('/')) return const GoHomeTarget();
  for (final (prefix, hasVideo) in [
    ('${Routes.video}/', true),
    ('${Routes.survey}/', false),
  ]) {
    if (next.startsWith(prefix)) {
      final id = int.tryParse(next.substring(prefix.length));
      if (id == null) return const GoHomeTarget();
      return OpenCampaignTarget(campaignId: id, hasVideo: hasVideo);
    }
  }
  if (requiresAccount(next)) return GoLocationTarget(next);
  return const GoHomeTarget();
}

/// Route of the page that plays or asks about [campaign].
String campaignRoute(Campaign campaign) => campaign.hasVideo
    ? '${Routes.video}/${campaign.id}'
    : '${Routes.survey}/${campaign.id}';

/// Called after a successful sign-in or registration. Goes where [next]
/// says. For a campaign the guest tapped it lands on Home first (so back
/// works) and then opens the campaign from the viewer's own targeted feed;
/// if it is not in that feed the viewer stays on Home with a short note.
Future<void> finishAuth(
  BuildContext context,
  String? next, {
  Future<List<Campaign>> Function()? loadFeed,
}) async {
  final router = GoRouter.of(context);
  switch (parsePostAuth(next)) {
    case GoHomeTarget():
      router.go(Routes.home);
    case GoLocationTarget(:final location):
      router.go(location);
    case OpenCampaignTarget(:final campaignId):
      router.go(Routes.home);
      var feed = const <Campaign>[];
      try {
        feed = await (loadFeed ?? ViewerService.instance.feed)();
      } catch (_) {
        // Treated like "not in the feed": the viewer stays on Home.
      }
      final match = feed.where((c) => c.id == campaignId);
      if (match.isEmpty) {
        rootMessengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(kCampaignGoneMessage)));
        return;
      }
      router.push(campaignRoute(match.first), extra: match.first);
  }
}
