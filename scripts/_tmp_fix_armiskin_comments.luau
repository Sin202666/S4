local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmSkin
local src = m.Source
local out = table.create(500)
local n1, n2 = 0, 0
for line in string.gmatch(src .. "\n", "(.-)\n") do
	if string.match(line, "^\t%-%- MeshPart") then
		line = "\t-- MeshPart 几何在属性上，不依赖子网格；普通 Part（R6）需 SpecialMesh 才有圆润边"
		n1 += 1
	elseif string.match(line, "^\t%-%- 保留肢体外形") then
		line = "\t-- 保留肢体外形网格，只清 Weld / 粒子等；否则能量壳又变回尖角方块"
		n2 += 1
	end
	table.insert(out, line)
end
local newSrc = table.concat(out, "\n")
if not string.match(src, "\n$") and string.match(newSrc, "\n$") then
	-- keep no trailing newline if original lacked it
end
m.Source = newSrc
return string.format(
	"n1=%d n2=%d classic=%s ensure=%s meshCommentOk=%s shellCommentOk=%s",
	n1,
	n2,
	tostring(newSrc:find("CLASSIC_ARM_MESH", 1, true) ~= nil),
	tostring(newSrc:find("_ensureLimbMesh", 1, true) ~= nil),
	tostring(newSrc:find("才有圆润边", 1, true) ~= nil),
	tostring(newSrc:find("尖角方块", 1, true) ~= nil)
)
