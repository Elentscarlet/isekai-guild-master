"""Render the two requested readable, shareable single-image release posters."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
import argparse

ROOT=Path(__file__).resolve().parents[1]
BG='#efe5d5';PAPER='#fffaf0';INK='#343133';MUTED='#756b63';RUST='#874449';GOLD='#b19057'
REGULAR=Path('C:/Windows/Fonts/msyh.ttc')
BOLD=Path('C:/Windows/Fonts/msyhbd.ttc')
def font(size,bold=False):
    path=BOLD if bold and BOLD.exists() else REGULAR
    if not path.exists():path=ROOT/'GuildMaster-Godot-src/fonts/SourceHanSansLite.ttf'
    return ImageFont.truetype(str(path),size)

def lines(text,width,size):
    f=font(size);result=[]
    for paragraph in str(text).split('\n'):
        line=''
        for ch in paragraph:
            if f.getlength(line+ch)>width and line and ch not in '，。；：！？、）》」』】,.!?;:':result.append(line);line=ch
            else:line+=ch
        result.append(line)
    return result

def paragraph(draw,xy,text,width,size=30,color=INK,spacing=13):
    x,y=xy
    for line in lines(text,width,size):
        draw.text((x,y),line,font=font(size),fill=color);y+=size+spacing
    return y

def card_height(text,width=790):return 138+len(lines(text,width,30))*43+36

def header(image,kicker,title,subtitle):
    d=ImageDraw.Draw(image);d.rectangle((0,0,1800,24),fill=RUST)
    d.text((72,58),kicker,font=font(24,True),fill=RUST)
    d.text((68,105),title,font=font(66,True),fill=INK)
    paragraph(d,(72,204),subtitle,1656,28,MUTED)

def guide():
    data=json.loads((ROOT/'docs/dlc-guide.json').read_text('utf8'));rows=[]
    sections=data['sections']
    for i in range(0,len(sections),2):
        group=sections[i:i+2];rows.append((group,max(card_height(s[3]) for s in group)))
    total=330+sum(h+24 for _,h in rows)+230
    image=Image.new('RGB',(1800,total),BG);header(image,'PLAY GUIDE  /  全扩充速查',data['title'],data['subtitle'])
    d=ImageDraw.Draw(image);y=320
    for group,height in rows:
        for j,(number,title,tag,body) in enumerate(group):
            x=60+j*852;d.rounded_rectangle((x,y,x+828,y+height),radius=14,fill=PAPER,outline='#d0bda6',width=2)
            d.rounded_rectangle((x+22,y+24,x+82,y+79),radius=8,fill=RUST)
            d.text((x+30,y+28),number,font=font(29,True),fill='white')
            d.text((x+102,y+23),title,font=font(33,True),fill=INK)
            d.text((x+26,y+88),tag,font=font(23),fill=RUST)
            paragraph(d,(x+26,y+136),body,776,30)
        y+=height+24
    d.line((72,y+12,1728,y+12),fill=GOLD,width=3)
    paragraph(d,(72,y+42),data['footer'],1656,25,MUTED)
    image.save(ROOT/'docs/DLC玩法总览.png',optimize=True)
    print('Guide:',image.size)

def release_notes():
    blocks=[
      ('台湾友人 · v4.0 refactor',[
        ('卡牌与规则','核对事件、王权与人物能力的费用、门槛、标记和结算顺序；区分单人／多人卡面与效果，客户端和服务器共用规则。'),
        ('扫描卡面与美术','接入实体扫描卡、人物与场景素材，保留纸面与漫画边框；调整庆典卡面，改善动态套字残影。'),
        ('繁简切换与操作','增加繁体中文及配套字体；优化成就、秘药、好感、行动与资源面板，保留选牌滚动位置，强化放大、玩家详情与开局设置。'),
        ('同机客座与存档','支持2–5人同机轮流操作，交接时确认席位，遮挡私密信息；支持客座改名与本机进度保存／读取。'),
        ('扩充指南与判定','内置扩充玩法；修正龙与龙蛋显示、讨伐支付、森林净化、深渊夺宝、委托及旗标贡献联动。')]),
      ('本次更新 · v4.1.0',[
        ('截图人物与专属事件','提取34张卡面并作透视校正。希芙、芙莉达、贝露、霍伦、玛尔塔加入11套不同能力的可选版本；同名旧版继续保留。加入玛尔塔专属「懒散生活」。'),
        ('蓓尔被动修复','按印刷费用个位数0或5触发，覆盖10、15、20、25等卡；不会误用折扣后的实付费用。得到2金币并从专用牌抽1张的流程保持一致。'),
        ('艾露单人修正','依据日文扩展规则书第17页：艾露背面在单人中替换为皮耶利亚背面，包含初始资产和升级。选角显示替换卡面与说明；多人仍使用艾露原能力。'),
        ('全角色中日双语配音','覆盖25个人物名称、57个可选版本，共1134份语音素材，日语与中文各567份。配音默认关闭，开启后默认日语；设置可切换中文、独立调音量及选择人物试听。日语优先采用用户提供的13组录音，缺少片段与中文沿用已有配音，全部随包离线播放。'),
        ('默认简体与经典布局','新安装默认简体中文，保留繁体切换。对局桌面沿用经典布局：地图、王权命令与手牌集中展示，保留现有配色与纸面。'),
        ('完整发行与玩法长图','修复基础包缺少启动场景、运行库及外部素材路径的问题；同步离线与服务端规则。另附一张覆盖全部扩充、地图与房间变体的玩法长图。')]),
      ('修复更新 · v4.1.1',[
        ('连接超时与自动重试','修复部分网络中能连接端口、却收不到游戏回应的问题。普通连接未获确认时自动通过备用通道重试；已验证服务器欢迎、房间目录、建房、加入、重连与退出。'),
        ('配音默认关闭','新安装默认关闭配音；旧版自动保存的开启状态会一次性迁移为关闭。之后手动开启仍可保存，日语与中文选择、独立音量及现有录音保持可用。'),
        ('人物立绘来源','为此前裁切卡面的希芙、芙莉达、贝露、霍伦、玛尔塔制作10张独立立绘，覆盖11个规则版本；黑白版本保留各自外观，其余角色沿用现有立绘。规则详情仍可查看完整卡牌。')])]
    rendered=[]
    for section,items in blocks:
        height=116+sum(65+len(lines(body,1584,30))*43+28 for _,body in items)
        rendered.append((section,items,height))
    total=330+sum(h+28 for _,_,h in rendered)+850+210
    image=Image.new('RGB',(1800,total),BG);header(image,'RELEASE NOTES  /  2026.11.01','异世界公会长 · 更新日志','台湾友人 v4.0 的改进 ＋ v4.1 内容更新 ＋ v4.1.1 修复')
    d=ImageDraw.Draw(image);y=320
    for section,items,height in rendered:
        d.rounded_rectangle((60,y,1740,y+height),radius=16,fill=PAPER,outline='#d0bda6',width=2)
        d.rectangle((60,y,1740,y+85),fill=RUST);d.text((92,y+18),section,font=font(37,True),fill='white');cy=y+114
        for title,body in items:
            d.text((98,cy),title,font=font(34,True),fill=RUST);cy+=62
            cy=paragraph(d,(98,cy),body,1584,30)+28
        y+=height+28
    d.text((72,y+6),'同一配色，经典桌面',font=font(39,True),fill=INK);y+=86
    for index,(name,label) in enumerate([('classic-5','经典布局')]):
        shot=ROOT/'qa'/(name+'.png')
        if shot.exists():
            im=Image.open(shot).convert('RGB');im.thumbnail((804,456),Image.Resampling.LANCZOS)
            x=72+index*852;image.paste(im,(x,y));d.text((x,y+475),label,font=font(28,True),fill=RUST)
    y+=565
    paragraph(d,(72,y),'基于 cat90132-beep/isekai-guild-master 的 refactor 标签继续开发。感谢台湾友人的修改与整理；游戏美术及第三方组件保留原作者署名与许可。',1656,27,MUTED)
    image=image.crop((0,0,1800,min(total,y+210)))
    image.save(ROOT/'docs/更新日志_4.1.png',optimize=True);print('Release notes:',image.size)

def release_notes_42():
    version=json.loads((ROOT/'release.json').read_text('utf8'))['version']
    items=[
        ('死灵王的大军势计分修复','每张带战力支付图示的正面事件卡计2分，包含自身；实际是否使用战力支付不影响计分。重复卡逐张计算，终局正常结算。'),
        ('妖狐封印费用修复','「被诅咒的妖狐的封印」正确费用为9金币。卡牌说明、费用显示与实际扣费同步修正。'),
        ('行动倒计时恢复显示','经典桌面与手机版均显示基础时间和备用时间；等待服务器快照时持续更新，顶部计时不会被按钮遮挡。'),
        ('聊天改为滚动弹幕','消息以「玩家名：内容」飘过画面。发送框可收起，聊天不再占用卡牌结算弹窗。'),
        ('斯卡蒂白版支付修复','普通事件卡、王权和其他金币费用可选择投入战力，允许保留金币。每点战力抵5金币，超额抵付不找零。'),
        ('人物升级与等级显示','人物升级时显示提示；人物详情默认打开当前等级卡面，桌面与公会详情同步显示等级。'),
        ('行动提示窗顶部居中','提示窗位于顶部状态栏下方，水平方向居中；背景半透明，文字保持清晰。鼠标点击或手机轻触即可隐藏，后续新行动仍正常提示。'),
        ('Phrase百货结算核验','按已打出正面事件卡的当前声望结算，包含计数标记与可变声望，忽略翻面卡；结算回归测试通过。'),
    ]
    rows=[]
    for index in range(0,len(items),2):
        pair=items[index:index+2]
        height=105+max(len(lines(body,750,31))*47 for _,body in pair)+30
        rows.append((pair,height))
    shot=Image.open(ROOT/'qa/popup-top-center/mobile-action-popup.png').convert('RGB')
    shot=shot.resize((1656,round(1656*shot.height/shot.width)),Image.Resampling.LANCZOS)
    total=570+sum(h+24 for _,h in rows)+220+shot.height+240
    image=Image.new('RGB',(1800,total),BG)
    header(image,'RELEASE NOTES  /  2026.11.16','异世界公会长 · v'+version,'本轮修复汇总  /  行动提示窗顶部居中 · 死灵王计分修复')
    d=ImageDraw.Draw(image)
    d.rounded_rectangle((60,320,1740,540),radius=16,fill=PAPER,outline=GOLD,width=3)
    d.text((94,340),'本次修复重点',font=font(30,True),fill=RUST)
    d.text((94,392),'行动提示：顶部居中 · 半透明 · 点击隐藏',font=font(45,True),fill=INK)
    paragraph(d,(96,469),'死灵王按带战力支付图示的正面事件卡数量×2计分（包含自身）。',1530,28,MUTED)
    y=570
    for pair,height in rows:
        for j,(title,body) in enumerate(pair):
            x=60+j*852
            d.rounded_rectangle((x,y,x+828,y+height),radius=14,fill=PAPER,outline='#d0bda6',width=2)
            d.text((x+30,y+25),title,font=font(35,True),fill=RUST)
            paragraph(d,(x+30,y+93),body,750,31,INK,16)
        y+=height+24
    d.text((72,y+12),'Android手机版 · 横屏触控',font=font(43,True),fill=INK)
    paragraph(d,(72,y+82),'放大字体与主要按钮，重排桌面、选牌、出牌与效果结算界面。\n包含离线单人、2–5人同机客座与本机存档；沿用桌面版规则引擎。',1656,31,INK,14)
    y+=220
    image.paste(shot,(72,y));y+=shot.height+32
    d.line((72,y,1728,y),fill=GOLD,width=3)
    paragraph(d,(72,y+24),'Windows / Android / 服务端同步提供更新包。联机请同步更新服务端。',1656,27,INK)
    paragraph(d,(72,y+75),'Android 7.0+，ARM64 / x86_64。APK已打包并通过签名检查，安卓设备运行待实测。',1656,24,MUTED)
    d.text((72,y+128),'github.com/shuiwen879867/isekai-guild-master',font=font(23),fill=MUTED)
    target=ROOT/'docs/更新日志_4.2.png';image.save(target,optimize=True)
    print('Current release poster:',image.size,target.name)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--current-only',action='store_true');args=parser.parse_args()
    if not args.current_only:guide();release_notes()
    release_notes_42()
