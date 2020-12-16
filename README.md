# 2020-2021 Parking Notifier

This is just a quick script that will take a comma-separated list of dates and send an email when it finds available events.

This uses the [postmark](https://postmarkapp.com) smtp service to send email notifications.

## Example

```
docker run -d \
       -e FROM_EMAIL="from@example.com" \
       -e TO_EMAIL="to@example.com"" \
       -e SUBJECT="Parking Results" \
       -e DATES="1/11/2020,1/3/2020,5/17/2020" \
       -e POSTMARK_API="api-key" \
       -e SKIP_PAID=false \
       ghcr.io/kwatson/parking:latest
```