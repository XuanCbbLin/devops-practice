import https from "https";

const DISCORD_WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL;

export const handler = async (event) => {
    console.log("Received event:", JSON.stringify(event, null, 2));

    for (const record of event.Records) {
        const bucket = record.s3.bucket.name;
        const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, " "));
        const message = `📦 有新檔案上傳！\nBucket: **${bucket}**\nFile: **${key}**`;
        await sendDiscordMessage(message);
    }

    return { statusCode: 200, body: "Notification sent" };
};

function sendDiscordMessage(content) {
    return new Promise((resolve, reject) => {
        const data = JSON.stringify({ content });
        const url = new URL(DISCORD_WEBHOOK_URL);

        const options = {
            hostname: url.hostname,
            path: url.pathname + url.search,
            method: "POST",
            headers: { "Content-Type": "application/json" },
        };

        const req = https.request(options, (res) => {
            res.on("end", () => resolve());
        });

        req.on("error", reject);
        req.write(data);
        req.end();
    });
}
