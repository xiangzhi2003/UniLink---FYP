/// A user-filed report as the admin panel sees it (joined display names
/// included). Regular users only ever *insert* reports; reading them is
/// admin-only via the backend.
class Report {
  final String id;
  final String reason;
  final String status; // open | resolved
  final DateTime createdAt;
  final String? reporterName;
  final String? listingId;
  final String? listingTitle; // set when a listing was reported
  final String? reportedUserId;
  final String? reportedUserName; // set when a user was reported

  const Report({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reporterName,
    this.listingId,
    this.listingTitle,
    this.reportedUserId,
    this.reportedUserName,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      reporterName: json['reporter_name'] as String?,
      listingId: json['listing_id'] as String?,
      listingTitle: json['listing_title'] as String?,
      reportedUserId: json['reported_user_id'] as String?,
      reportedUserName: json['reported_user_name'] as String?,
    );
  }
}
