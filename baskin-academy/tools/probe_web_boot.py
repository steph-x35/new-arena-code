import asyncio, sys, json
from playwright.async_api import async_playwright

URL = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8080/"
SHOT = sys.argv[2] if len(sys.argv) > 2 else "/home/user/web_shot.png"
WAIT = float(sys.argv[3]) if len(sys.argv) > 3 else 25.0

async def main():
    logs = []
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=[
            "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
            "--no-sandbox", "--disable-dev-shm-usage", "--autoplay-policy=no-user-gesture-required",
        ])
        ctx = await browser.new_context(viewport={"width":1280,"height":720})
        page = await ctx.new_page()
        page.on("console", lambda m: logs.append("[console.%s] %s" % (m.type, m.text)))
        page.on("pageerror", lambda e: logs.append("[pageerror] %s" % e))
        page.on("requestfailed", lambda r: logs.append("[reqfail] %s %s" % (r.url, r.failure)))
        await page.goto(URL, wait_until="domcontentloaded")
        await asyncio.sleep(WAIT)
        info = await page.evaluate("""() => {
          const c = document.querySelector('canvas');
          return { canvas: c ? {w:c.width,h:c.height} : null,
                   status: (document.querySelector('#status')||{}).textContent || '',
                   title: document.title };
        }""")
        await page.screenshot(path=SHOT)
        await browser.close()
    print(json.dumps(info, indent=2))
    print("\n".join(logs[-40:]))

asyncio.run(main())
