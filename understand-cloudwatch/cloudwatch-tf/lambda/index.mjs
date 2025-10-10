import https from "https";

/**
 * 將訊息 POST 到 Discord webhook
 */
const postToDiscord = (url, body) =>
    new Promise((resolve, reject) => {
        try {
            const u = new URL(url);
            const req = https.request(
                {
                    hostname: u.hostname,
                    path: u.pathname + u.search,
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                },
                (res) => {
                    let data = "";
                    res.on("data", (chunk) => (data += chunk));
                    res.on("end", () => resolve({ status: res.statusCode, data }));
                }
            );
            req.on("error", reject);
            req.write(JSON.stringify(body));
            req.end();
        } catch (err) {
            reject(err);
        }
    });

/**
 * Lambda handler
 */
export const handler = async (event) => {
    const webhook = process.env.DISCORD_WEBHOOK_URL;

    if (!webhook || !/^https?:\/\//.test(webhook)) {
        console.error("❌ DISCORD_WEBHOOK_URL 未設定或格式錯誤:", webhook);
        throw new Error("Missing or invalid Discord Webhook URL");
    }

    // 支援 SNS Event 或直接測試事件
    const sns = event?.Records?.[0]?.Sns;
    const msg = sns ? JSON.parse(sns.Message) : event;

    const alarmName = msg.AlarmName || "UnknownAlarm";
    const state = msg.NewStateValue || "ALARM";
    const reason = msg.NewStateReason || "No reason provided.";
    const metric = msg.Trigger?.MetricName || "CPUUtilization";
    const instanceId = msg.Trigger?.Dimensions?.find((d) => d.name === "InstanceId")?.value || "-";

    const content = `⚠️ **CloudWatch Alarm Triggered**
> **Alarm:** ${alarmName}
> **State:** ${state}
> **Metric:** ${metric}
> **InstanceId:** ${instanceId}
> **Reason:** ${reason}`;

    try {
        const res = await postToDiscord(webhook, { content });
        console.log("✅ Discord 回應:", res);
        return { statusCode: res.status, body: "Message sent to Discord." };
    } catch (error) {
        console.error("❌ 傳送 Discord 失敗:", error);
        return { statusCode: 500, body: "Error sending to Discord." };
    }
};
