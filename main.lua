local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Library = {
	Elements = {},
	ThemeObjects = {},
	Connections = {},
	Flags = {},
	Themes = {
		Default = {
			Main = Color3.fromRGB(18, 18, 20),
			Second = Color3.fromRGB(25, 25, 28),
			Stroke = Color3.fromRGB(45, 45, 50),
			Divider = Color3.fromRGB(35, 35, 40),
			Text = Color3.fromRGB(245, 245, 245),
			TextDark = Color3.fromRGB(170, 170, 175),
			Accent = Color3.fromRGB(0, 120, 215),
			Glow = Color3.fromRGB(0, 0, 0)
		}
	},
	SelectedTheme = "Default",
	Folder = nil,
	SaveCfg = false,
	Font = Enum.Font.GothamMedium,
	HeaderFont = Enum.Font.GothamBold
}

local function GetIcon(IconName)
	if not IconName then return "" end
	return IconName
end

function Library:CleanupInstance()
	for _, instance in pairs(CoreGui:GetChildren()) do
		if instance:IsA("ScreenGui") and instance.Name:match("^[A-Z]%d%d%d$") then 
			instance:Destroy()
		end
	end
end

Library:CleanupInstance() 

local Container = Instance.new("ScreenGui")
Container.Name = string.char(math.random(65, 90))..tostring(math.random(100, 999))
Container.DisplayOrder = 1000
Container.Parent = CoreGui
Container.IgnoreGuiInset = true

function Library:IsRunning()
	return Container and Container.Parent == CoreGui
end

local function AddConnection(Signal, Function)
	if (not Library:IsRunning()) then
		return
	end
	local SignalConnect = Signal:Connect(Function)
	table.insert(Library.Connections, SignalConnect)
	return SignalConnect
end

task.spawn(function()
	while (Library:IsRunning()) do
		task.wait()
	end

	for _, Connection in next, Library.Connections do
		Connection:Disconnect()
	end
end)

local function MakeDraggable(DragPoint, Main)
	pcall(function()
		local Dragging, DragInput, MousePos, FramePos = false
		DragPoint.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Dragging = true
				MousePos = Input.Position
				FramePos = Main.Position

				Input.Changed:Connect(function()
					if Input.UserInputState == Enum.UserInputState.End then
						Dragging = false
					end
				end)
			end
		end)
		DragPoint.InputChanged:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
				DragInput = Input
			end
		end)
		UserInputService.InputChanged:Connect(function(Input)
			if Input == DragInput and Dragging then
				local Delta = Input.Position - MousePos
				TweenService:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
					Position = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
				}):Play()
			end
		end)
	end)
end  

local function Create(Name, Properties, Children)
	local Object = Instance.new(Name)
	for i, v in next, Properties or {} do
		Object[i] = v
	end
	for i, v in next, Children or {} do
		v.Parent = Object
	end
	return Object
end

local function CreateElement(ElementName, ElementFunction)
	Library.Elements[ElementName] = function(...)
		return ElementFunction(...)
	end
end

local function MakeElement(ElementName, ...)
	local NewElement = Library.Elements[ElementName](...)
	return NewElement
end

local function SetProps(Element, Props)
	table.foreach(Props, function(Property, Value)
		Element[Property] = Value
	end)
	return Element
end

local function SetChildren(Element, Children)
	table.foreach(Children, function(_, Child)
		Child.Parent = Element
	end)
	return Element
end

local function Round(Number, Factor)
	local Result = math.floor(Number/Factor + (math.sign(Number) * 0.5)) * Factor
	if Result < 0 then Result = Result + Factor end
	return Result
end

local function ReturnProperty(Object)
	if Object:IsA("Frame") or Object:IsA("TextButton") then
		return "BackgroundColor3"
	end 
	if Object:IsA("ScrollingFrame") then
		return "ScrollBarImageColor3"
	end 
	if Object:IsA("UIStroke") then
		return "Color"
	end 
	if Object:IsA("TextLabel") or Object:IsA("TextBox") then
		return "TextColor3"
	end   
	if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then
		return "ImageColor3"
	end   
end

local function AddThemeObject(Object, Type)
	if not Library.ThemeObjects[Type] then
		Library.ThemeObjects[Type] = {}
	end    
	table.insert(Library.ThemeObjects[Type], Object)
	Object[ReturnProperty(Object)] = Library.Themes[Library.SelectedTheme][Type]
	return Object
end    

local function SetTheme()
	for Name, Type in pairs(Library.ThemeObjects) do
		for _, Object in pairs(Type) do
			Object[ReturnProperty(Object)] = Library.Themes[Library.SelectedTheme][Name]
		end    
	end    
end

local function PackColor(Color)
	return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end    

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

local function LoadCfg(Config)
	local Data = HttpService:JSONDecode(Config)
	table.foreach(Data, function(a,b)
		if Library.Flags[a] then
			spawn(function() 
				if Library.Flags[a].Type == "Colorpicker" then
					Library.Flags[a]:Set(UnpackColor(b))
				else
					Library.Flags[a]:Set(b)
				end    
			end)
		else
			warn("Configuration Loader skipping missing flag: ", a)
		end
	end)
end

local function SaveCfg(Name)
	local Data = {}
	for i,v in pairs(Library.Flags) do
		if v.Save then
			if v.Type == "Colorpicker" then
				Data[i] = PackColor(v.Value)
			else
				Data[i] = v.Value
			end
		end	
	end
	writefile(Library.Folder .. "/" .. Name .. ".txt", HttpService:JSONEncode(Data))
end

local WhitelistedMouse = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,Enum.UserInputType.MouseButton3,Enum.UserInputType.Touch}
local BlacklistedKeys = {Enum.KeyCode.Unknown,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Up,Enum.KeyCode.Left,Enum.KeyCode.Down,Enum.KeyCode.Right,Enum.KeyCode.Slash,Enum.KeyCode.Tab,Enum.KeyCode.Backspace,Enum.KeyCode.Escape}

local function CheckKey(Table, Key)
	for _, v in next, Table do
		if v == Key then
			return true
		end
	end
end

local function Ripple(Obj)
	spawn(function()
		local Mouse = LocalPlayer:GetMouse()
		local RippleCircle = Instance.new("ImageLabel")
		RippleCircle.Name = "Ripple"
		RippleCircle.Parent = Obj
		RippleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		RippleCircle.BackgroundTransparency = 1.000
		RippleCircle.ZIndex = 10
		RippleCircle.Image = "rbxassetid://2708891598"
		RippleCircle.ImageColor3 = Color3.fromRGB(255, 255, 255)
		RippleCircle.ImageTransparency = 0.800
		RippleCircle.ScaleType = Enum.ScaleType.Fit
		RippleCircle.Position = UDim2.new((Mouse.X - RippleCircle.AbsolutePosition.X) / Obj.AbsoluteSize.X, 0, (Mouse.Y - RippleCircle.AbsolutePosition.Y) / Obj.AbsoluteSize.Y, 0)
		local RippleTween = TweenService:Create(RippleCircle, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(-5.5, 0, -5.5, 0), Size = UDim2.new(12, 0, 12, 0)})
		local FadeTween = TweenService:Create(RippleCircle, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {ImageTransparency = 1})
		RippleTween:Play()
		FadeTween:Play()
		wait(0.5)
		RippleCircle:Destroy()
	end)
end

CreateElement("Corner", function(Scale, Offset)
	local Corner = Create("UICorner", {
		CornerRadius = UDim.new(Scale or 0, Offset or 8)
	})
	return Corner
end)

CreateElement("Stroke", function(Color, Thickness)
	local Stroke = Create("UIStroke", {
		Color = Color or Color3.fromRGB(255, 255, 255),
		Thickness = Thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	})
	return Stroke
end)

CreateElement("List", function(Scale, Offset)
	local List = Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(Scale or 0, Offset or 6)
	})
	return List
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
	local Padding = Create("UIPadding", {
		PaddingBottom = UDim.new(0, Bottom or 6),
		PaddingLeft = UDim.new(0, Left or 6),
		PaddingRight = UDim.new(0, Right or 6),
		PaddingTop = UDim.new(0, Top or 6)
	})
	return Padding
end)

CreateElement("TFrame", function()
	local TFrame = Create("Frame", {
		BackgroundTransparency = 1
	})
	return TFrame
end)

CreateElement("Frame", function(Color)
	local Frame = Create("Frame", {
		BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0
	})
	return Frame
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
	local Frame = Create("Frame", {
		BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0
	}, {
		Create("UICorner", {
			CornerRadius = UDim.new(Scale, Offset)
		})
	})
	return Frame
end)

CreateElement("Button", function()
	local Button = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0
	})
	return Button
end)

CreateElement("ScrollFrame", function(Color, Width)
	local ScrollFrame = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		MidImage = "rbxassetid://7445543667",
		BottomImage = "rbxassetid://7445543667",
		TopImage = "rbxassetid://7445543667",
		ScrollBarImageColor3 = Color,
		BorderSizePixel = 0,
		ScrollBarThickness = Width,
		CanvasSize = UDim2.new(0, 0, 0, 0)
	})
	return ScrollFrame
end)

CreateElement("Image", function(ImageID)
	local ImageNew = Create("ImageLabel", {
		Image = ImageID,
		BackgroundTransparency = 1
	})

	if GetIcon(ImageID) ~= "" then
		ImageNew.Image = GetIcon(ImageID)
	end	

	return ImageNew
end)

CreateElement("Label", function(Text, TextSize, Transparency)
	local Label = Create("TextLabel", {
		Text = Text or "",
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextTransparency = Transparency or 0,
		TextSize = TextSize or 14,
		Font = Library.Font,
		RichText = true,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	return Label
end)

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
	SetProps(MakeElement("List"), {
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 8)
	})
}), {
	Position = UDim2.new(1, -20, 1, -20),
	Size = UDim2.new(0, 300, 1, -20),
	AnchorPoint = Vector2.new(1, 1),
	Parent = Container
})

function Library:MakeNotification(NotificationConfig)
	spawn(function()
		NotificationConfig.Name = NotificationConfig.Name or "System"
		NotificationConfig.Content = NotificationConfig.Content or "Notification"
		NotificationConfig.Image = NotificationConfig.Image or "rbxassetid://4483345998"
		NotificationConfig.Time = NotificationConfig.Time or 5

		local NotificationParent = SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = NotificationHolder
		})

		local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", Library.Themes[Library.SelectedTheme].Main, 0, 8), {
			Parent = NotificationParent, 
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(1, 320, 0, 0),
			BackgroundTransparency = 0.05,
			AutomaticSize = Enum.AutomaticSize.Y
		}), {
			MakeElement("Stroke", Library.Themes[Library.SelectedTheme].Stroke, 1),
			MakeElement("Padding", 12, 12, 12, 12),
			SetProps(MakeElement("Image", NotificationConfig.Image), {
				Size = UDim2.new(0, 24, 0, 24),
				ImageColor3 = Library.Themes[Library.SelectedTheme].Accent,
				Name = "Icon"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Name, 15), {
				Size = UDim2.new(1, -30, 0, 24),
				Position = UDim2.new(0, 34, 0, 0),
				Font = Library.HeaderFont,
				TextColor3 = Library.Themes[Library.SelectedTheme].Text,
				Name = "Title"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Content, 13), {
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 30),
				Font = Library.Font,
				Name = "Content",
				AutomaticSize = Enum.AutomaticSize.Y,
				TextColor3 = Library.Themes[Library.SelectedTheme].TextDark,
				TextWrapped = true
			})
		})
		
		TweenService:Create(NotificationFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
		
		wait(NotificationConfig.Time)
		
		TweenService:Create(NotificationFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(1, 350, 0, 0)}):Play()
		wait(0.6)
		NotificationParent:Destroy()
	end)
end    

function Library:Init()
	if Library.SaveCfg then	
		pcall(function()
			if isfile(Library.Folder .. "/" .. game.GameId .. ".txt") then
				LoadCfg(readfile(Library.Folder .. "/" .. game.GameId .. ".txt"))
				Library:MakeNotification({
					Name = "Config Loader",
					Content = "Successfully loaded configuration for " .. game.GameId,
					Time = 4
				})
			end
		end)		
	end	
end	

function Library:MakeWindow(WindowConfig)
	local FirstTab = true
	local Minimized = false
	local UIHidden = false

	WindowConfig = WindowConfig or {}
	WindowConfig.Name = WindowConfig.Name or "UI Library"
	WindowConfig.ConfigFolder = WindowConfig.ConfigFolder or "OrionConfig"
	WindowConfig.SaveConfig = WindowConfig.SaveConfig or false
	WindowConfig.IntroEnabled = WindowConfig.IntroEnabled or true
	WindowConfig.IntroText = WindowConfig.IntroText or "Initializing..."
	WindowConfig.CloseCallback = WindowConfig.CloseCallback or function() end
	WindowConfig.ShowIcon = WindowConfig.ShowIcon or true
	WindowConfig.Icon = WindowConfig.Icon or "rbxassetid://4483345998"
	WindowConfig.IntroIcon = WindowConfig.IntroIcon or "rbxassetid://4483345998"
	
	Library.Folder = WindowConfig.ConfigFolder
	Library.SaveCfg = WindowConfig.SaveConfig

	if WindowConfig.SaveConfig then
		if not isfolder(Library.Folder) then
			makefolder(Library.Folder)
		end	
	end

	local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255), 2), {
		Size = UDim2.new(0, 160, 1, -55),
		Position = UDim2.new(0, 0, 0, 55),
		CanvasSize = UDim2.new(0, 0, 0, 0)
	}), {
		MakeElement("List", 0, 4),
		MakeElement("Padding", 10, 8, 8, 10)
	}), "Divider")

	AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 20)
	end)

	local CloseBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size = UDim2.new(0, 24, 0, 24),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://3926305904"), {
			Size = UDim2.new(0, 20, 0, 20),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5)
		}), "TextDark")
	})

	local MinimizeBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size = UDim2.new(0, 24, 0, 24),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://3926307971"), {
			Size = UDim2.new(0, 20, 0, 20),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5)
		}), "TextDark")
	})

	local DragPoint = SetProps(MakeElement("TFrame"), {
		Size = UDim2.new(1, 0, 0, 50)
	})

	local WindowFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 12), {
		Parent = Container,
		Position = UDim2.new(0.5, -325, 0.5, -200),
		Size = UDim2.new(0, 650, 0, 400),
		ClipsDescendants = false 
	}), {
		AddThemeObject(SetProps(MakeElement("Stroke"), {
			Transparency = 0.5
		}), "Stroke"),
		
		SetProps(MakeElement("Image", "rbxassetid://1316045217"), {
			Name = "Shadow",
			Position = UDim2.new(0, -15, 0, -15),
			Size = UDim2.new(1, 30, 1, 30),
			ImageColor3 = Color3.fromRGB(0, 0, 0),
			ImageTransparency = 0.4,
			SliceCenter = Rect.new(10, 10, 118, 118),
			ScaleType = Enum.ScaleType.Slice,
			ZIndex = -1
		}),

		SetChildren(SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 55),
			Name = "TopBar"
		}), {
			AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 18), {
				Size = UDim2.new(1, -200, 1, 0),
				Position = UDim2.new(0, 50, 0, 0),
				Font = Library.HeaderFont
			}), "Text"),
			
			AddThemeObject(SetProps(MakeElement("Image", WindowConfig.Icon), {
				Size = UDim2.new(0, 24, 0, 24),
				Position = UDim2.new(0, 15, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5)
			}), "Accent"),

			SetChildren(SetProps(MakeElement("List"), {
				Padding = UDim.new(0, 5),
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center
			}), {
				Parent = nil 
			}),
			
			SetChildren(SetProps(MakeElement("TFrame"), {
				Size = UDim2.new(0, 100, 1, 0),
				Position = UDim2.new(1, -15, 0, 0),
				AnchorPoint = Vector2.new(1, 0)
			}), {
				MakeElement("List", 0, 5),
				SetProps(MakeElement("Padding", 0, 0, 0, 0), {}),
				CloseBtn,
				MinimizeBtn
			})
		}),
		
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 0, 55)
		}), "Divider"),

		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(0, 1, 1, -55),
			Position = UDim2.new(0, 160, 0, 55)
		}), "Divider"),

		DragPoint,
		TabHolder
	}), "Main")

	MakeDraggable(DragPoint, WindowFrame)

	local MobileReopenButton = SetChildren(SetProps(MakeElement("Button"), {
		Parent = Container,
		Size = UDim2.new(0, 45, 0, 45),
		Position = UDim2.new(0.5, -22, 0, 20),
		BackgroundColor3 = Library.Themes[Library.SelectedTheme].Main,
		Visible = false
	}), {
		AddThemeObject(SetProps(MakeElement("Image", WindowConfig.Icon), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0.5, 0, 0.5, 0),
			ImageColor3 = Library.Themes[Library.SelectedTheme].Accent
		}), "Text"),
		MakeElement("Corner", 0, 12),
		MakeElement("Stroke", Library.Themes[Library.SelectedTheme].Stroke)
	})

	AddConnection(CloseBtn.MouseButton1Click, function()
		WindowFrame.Visible = false
		if UserInputService.TouchEnabled then
			MobileReopenButton.Visible = true
		end
		UIHidden = true
		Library:MakeNotification({
			Name = "Interface Hidden",
			Content = "Press RightControl to reopen.",
			Time = 4
		})
		WindowConfig.CloseCallback()
	end)

	AddConnection(UserInputService.InputBegan, function(Input)
		if Input.KeyCode == Enum.KeyCode.RightControl and UIHidden then
			WindowFrame.Visible = true
			MobileReopenButton.Visible = false
			UIHidden = false
		end
	end)
	
	AddConnection(MobileReopenButton.Activated, function()
		WindowFrame.Visible = true
		MobileReopenButton.Visible = false
		UIHidden = false
	end)

	AddConnection(MinimizeBtn.MouseButton1Click, function()
		Minimized = not Minimized
		if Minimized then
			TweenService:Create(WindowFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 650, 0, 55)}):Play()
			WindowFrame.ClipsDescendants = true
		else
			TweenService:Create(WindowFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 650, 0, 400)}):Play()
			spawn(function()
				wait(0.4)
				WindowFrame.ClipsDescendants = false
			end)
		end
	end)

	local function LoadSequence()
		local OriginalScale = WindowFrame.Size
		WindowFrame.Size = UDim2.new(0, 0, 0, 0)
		WindowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		WindowFrame.Visible = true
		
		TweenService:Create(WindowFrame, TweenInfo.new(0.7, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = OriginalScale,
			Position = UDim2.new(0.5, -325, 0.5, -200)
		}):Play()
	end 

	if WindowConfig.IntroEnabled then
		WindowFrame.Visible = false
		wait(0.2)
		LoadSequence()
	else
		WindowFrame.Visible = true
	end

	local TabFunction = {}
	function TabFunction:MakeTab(TabConfig)
		TabConfig = TabConfig or {}
		TabConfig.Name = TabConfig.Name or "Tab"
		TabConfig.Icon = TabConfig.Icon or "rbxassetid://4483345998"

		local TabButton = SetChildren(SetProps(MakeElement("Button"), {
			Size = UDim2.new(1, 0, 0, 36),
			Parent = TabHolder,
			BackgroundColor3 = Library.Themes[Library.SelectedTheme].Second,
			BackgroundTransparency = 1 
		}), {
			MakeElement("Corner", 0, 6),
			AddThemeObject(SetProps(MakeElement("Image", TabConfig.Icon), {
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 18, 0, 18),
				Position = UDim2.new(0, 12, 0.5, 0),
				ImageTransparency = 0.5,
				Name = "Ico"
			}), "Text"),
			AddThemeObject(SetProps(MakeElement("Label", TabConfig.Name, 13), {
				Size = UDim2.new(1, -40, 1, 0),
				Position = UDim2.new(0, 40, 0, 0),
				Font = Library.Font,
				TextTransparency = 0.5,
				Name = "Title"
			}), "Text"),
			SetProps(MakeElement("Frame"), {
				Name = "ActiveBar",
				Size = UDim2.new(0, 3, 0.6, 0),
				Position = UDim2.new(0, 0, 0.2, 0),
				BackgroundColor3 = Library.Themes[Library.SelectedTheme].Accent,
				Transparency = 1
			}),
			MakeElement("Corner", 0, 2)
		})

		local TabContainer = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255), 2), {
			Size = UDim2.new(1, -170, 1, -65),
			Position = UDim2.new(0, 165, 0, 60),
			Parent = WindowFrame,
			Visible = false,
			Name = "Container"
		}), {
			MakeElement("List", 0, 8),
			MakeElement("Padding", 10, 5, 10, 5)
		}), "Divider")

		AddConnection(TabContainer.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			TabContainer.CanvasSize = UDim2.new(0, 0, 0, TabContainer.UIListLayout.AbsoluteContentSize.Y + 20)
		end)

		local function ActivateTab()
			for _, Tab in next, TabHolder:GetChildren() do
				if Tab:IsA("TextButton") then
					TweenService:Create(Tab.Ico, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0.5, ImageColor3 = Library.Themes[Library.SelectedTheme].Text}):Play()
					TweenService:Create(Tab.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0.5, TextColor3 = Library.Themes[Library.SelectedTheme].Text}):Play()
					TweenService:Create(Tab, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
					TweenService:Create(Tab.ActiveBar, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 1}):Play()
				end
			end
			for _, Container in next, WindowFrame:GetChildren() do
				if Container.Name == "Container" then
					Container.Visible = false
				end
			end

			TweenService:Create(TabButton.Ico, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0, ImageColor3 = Library.Themes[Library.SelectedTheme].Accent}):Play()
			TweenService:Create(TabButton.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0, TextColor3 = Library.Themes[Library.SelectedTheme].Text}):Play()
			TweenService:Create(TabButton, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0.9}):Play()
			TweenService:Create(TabButton.ActiveBar, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Transparency = 0}):Play()
			
			TabContainer.Visible = true
			TabContainer.CanvasPosition = Vector2.new(0,0)
			
			TabContainer.GroupTransparency = 1
			TweenService:Create(TabContainer, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
		end

		if FirstTab then
			FirstTab = false
			ActivateTab()
		end

		AddConnection(TabButton.MouseButton1Click, ActivateTab)

		local ElementFunction = {}

		function ElementFunction:AddSection(SectionConfig)
			SectionConfig.Name = SectionConfig.Name or "Section"
			
			local SectionFrame = AddThemeObject(SetChildren(SetProps(MakeElement("Frame"), {
				Size = UDim2.new(1, 0, 0, 30),
				Parent = TabContainer,
				BackgroundTransparency = 1
			}), {
				AddThemeObject(SetProps(MakeElement("Label", SectionConfig.Name, 12), {
					Size = UDim2.new(1, -10, 1, 0),
					Position = UDim2.new(0, 5, 0, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					Font = Library.HeaderFont,
					TextColor3 = Library.Themes[Library.SelectedTheme].TextDark
				}), "TextDark")
			}), "Second")
		end

		function ElementFunction:AddLabel(Text)
			local LabelContainer = AddThemeObject(SetChildren(SetProps(MakeElement("Frame"), {
				Size = UDim2.new(1, 0, 0, 26),
				Parent = TabContainer,
				BackgroundTransparency = 1
			}), {
				AddThemeObject(SetProps(MakeElement("Label", Text, 14), {
					Size = UDim2.new(1, -10, 1, 0),
					Position = UDim2.new(0, 5, 0, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					Font = Library.Font
				}), "Text")
			}), "Second")

			local LabelLogic = {}
			function LabelLogic:Set(NewText)
				LabelContainer.TextLabel.Text = NewText
			end
			return LabelLogic
		end

		function ElementFunction:AddParagraph(Header, Content)
			local ParagraphFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Library.Themes[Library.SelectedTheme].Second, 0, 6), {
				Size = UDim2.new(1, 0, 0, 0),
				Parent = TabContainer,
				AutomaticSize = Enum.AutomaticSize.Y
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"),
				MakeElement("Padding", 10, 10, 10, 10),
				AddThemeObject(SetProps(MakeElement("Label", Header, 15), {
					Size = UDim2.new(1, 0, 0, 20),
					Font = Library.HeaderFont
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Label", Content, 13), {
					Size = UDim2.new(1, 0, 0, 0),
					Position = UDim2.new(0, 0, 0, 25),
					Font = Library.Font,
					AutomaticSize = Enum.AutomaticSize.Y,
					TextWrapped = true,
					TextTransparency = 0.3
				}), "Text")
			}), "Second")
			
			local ParagraphLogic = {}
			function ParagraphLogic:Set(NewHeader, NewContent)
				ParagraphFrame.TextLabel.Text = NewHeader
				ParagraphFrame.TextLabel_2.Text = NewContent
			end
			return ParagraphLogic
		end

		function ElementFunction:AddButton(ButtonConfig)
			ButtonConfig.Name = ButtonConfig.Name or "Button"
			ButtonConfig.Callback = ButtonConfig.Callback or function() end

			local ButtonFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Library.Themes[Library.SelectedTheme].Second, 0, 6), {
				Size = UDim2.new(1, 0, 0, 34),
				Parent = TabContainer
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"),
				AddThemeObject(SetProps(MakeElement("Label", ButtonConfig.Name, 14), {
					Size = UDim2.new(1, -20, 1, 0),
					Position = UDim2.new(0, 12, 0, 0),
					Font = Library.Font
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://10709791437"), {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.new(1, -26, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					ImageTransparency = 0.5
				}), "TextDark")
			}), "Second")

			local ButtonClick = SetProps(MakeElement("Button"), {
				Size = UDim2.new(1, 0, 1, 0),
				Parent = ButtonFrame
			})

			AddConnection(ButtonClick.MouseButton1Click, function()
				Ripple(ButtonFrame)
				ButtonConfig.Callback()
			end)
			
			AddConnection(ButtonClick.MouseEnter, function()
				TweenService:Create(ButtonFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}):Play()
				TweenService:Create(ButtonFrame.UIStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Color = Library.Themes[Library.SelectedTheme].Accent}):Play()
			end)
			
			AddConnection(ButtonClick.MouseLeave, function()
				TweenService:Create(ButtonFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Second}):Play()
				TweenService:Create(ButtonFrame.UIStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Color = Library.Themes[Library.SelectedTheme].Stroke}):Play()
			end)
		end

		function ElementFunction:AddToggle(ToggleConfig)
			ToggleConfig.Name = ToggleConfig.Name or "Toggle"
			ToggleConfig.Default = ToggleConfig.Default or false
			ToggleConfig.Callback = ToggleConfig.Callback or function() end
			ToggleConfig.Save = ToggleConfig.Save or false
			ToggleConfig.Flag = ToggleConfig.Flag or nil

			local Toggled = ToggleConfig.Default

			local ToggleFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Library.Themes[Library.SelectedTheme].Second, 0, 6), {
				Size = UDim2.new(1, 0, 0, 34),
				Parent = TabContainer
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"),
				AddThemeObject(SetProps(MakeElement("Label", ToggleConfig.Name, 14), {
					Size = UDim2.new(1, -60, 1, 0),
					Position = UDim2.new(0, 12, 0, 0),
					Font = Library.Font
				}), "Text")
			}), "Second")

			local SwitchFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Library.Themes[Library.SelectedTheme].Main, 0, 10), {
				Size = UDim2.new(0, 40, 0, 20),
				Position = UDim2.new(1, -50, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Parent = ToggleFrame
			}), {
				AddThemeObject(MakeElement("Stroke", Library.Themes[Library.SelectedTheme].Stroke, 1), "Stroke"),
				AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Library.Themes[Library.SelectedTheme].TextDark, 0, 8), {
					Size = UDim2.new(0, 16, 0, 16),
					Position = UDim2.new(0, 2, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Name = "Knob"
				}),{
					SetProps(MakeElement("Image", "rbxassetid://1316045217"), {
						Size = UDim2.new(1, 6, 1, 6),
						Position = UDim2.new(0.5, 0, 0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						ImageColor3 = Color3.new(0,0,0),
						ImageTransparency = 0.7,
						SliceCenter = Rect.new(10,10,118,118),
						ZIndex = 0
					})
				}), "TextDark")
			}), "Main")

			local ToggleButton = SetProps(MakeElement("Button"), {
				Size = UDim2.new(1, 0, 1, 0),
				Parent = ToggleFrame
			})

			local function UpdateToggle()
				if Toggled then
					TweenService:Create(SwitchFrame.Knob, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0, 22, 0.5, 0), BackgroundColor3 = Color3.new(1,1,1)}):Play()
					TweenService:Create(SwitchFrame.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = Library.Themes[Library.SelectedTheme].Accent}):Play()
					TweenService:Create(SwitchFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Accent}):Play()
				else
					TweenService:Create(SwitchFrame.Knob, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = Library.Themes[Library.SelectedTheme].TextDark}):Play()
					TweenService:Create(SwitchFrame.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = Library.Themes[Library.SelectedTheme].Stroke}):Play()
					TweenService:Create(SwitchFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Library.Themes[Library.SelectedTheme].Main}):Play()
				end
				ToggleConfig.Callback(Toggled)
			end

			AddConnection(ToggleButton.MouseButton1Click, function()
				Toggled = not Toggled
				UpdateToggle()
				if ToggleConfig.Flag then Library.Flags[ToggleConfig.Flag] = {Value = Toggled, Type = "Toggle", Save = ToggleConfig.Save} end
			end)
			
			if ToggleConfig.Flag then Library.Flags[ToggleConfig.Flag] = {Value = Toggled, Type = "Toggle", Save = ToggleConfig.Save} end
			UpdateToggle()
		end

		function ElementFunction:AddSlider(SliderConfig)
			SliderConfig.Name = SliderConfig.Name or "Slider"
			SliderConfig.Min = SliderConfig.Min or 0
			SliderConfig.Max = SliderConfig.Max or 100
			SliderConfig.Default = SliderConfig.Default or 50
			SliderConfig.Increment = SliderConfig.Increment or 1
			SliderConfig.Callback = SliderConfig.Callback or function() end
			SliderConfig.Flag = SliderConfig.Flag or nil
			SliderConfig.Save = SliderConfig.Save or false

			local SliderFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Library.Themes[Library.SelectedTheme].Second, 0, 6), {
				Size = UDim2.new(1, 0, 0, 50),
				Parent = TabContainer
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"),
				AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name, 14), {
					Size = UDim2.new(1, -20, 0, 24),
					Position = UDim2.new(0, 12, 0, 2),
					Font = Library.Font
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Label", tostring(SliderConfig.Default), 13), {
					Size = UDim2.new(0, 40, 0, 24),
					Position = UDim2.new(1, -50, 0, 2),
					Font = Library.Font,
					TextXAlignment = Enum.TextXAlignment.Right,
					Name = "ValueLabel"
				}), "TextDark")
			}), "Second")

			local SliderTrack = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Library.Themes[Library.SelectedTheme].Main, 0, 2), {
				Size = UDim2.new(1, -24, 0, 4),
				Position = UDim2.new(0, 12, 0, 32),
				Parent = SliderFrame
			}), {
				SetProps(MakeElement("RoundFrame", Library.Themes[Library.SelectedTheme].Accent, 0, 2), {
					Size = UDim2.new(0, 0, 1, 0),
					Name = "Fill"
				}),
			}), "Main")

			local SliderDot = SetChildren(SetProps(MakeElement("Button"), {
				Size = UDim2.new(0, 14, 0, 14),
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Parent = SliderTrack.Fill
			}), {
				MakeElement("Corner", 1, 0),
				SetProps(MakeElement("Frame", Color3.fromRGB(255,255,255)), {
					Size = UDim2.new(0, 14, 0, 14),
					Name = "Dot"
				}),
				MakeElement("Corner", 1, 0)
			})
			SliderDot.Dot.UICorner.CornerRadius = UDim.new(1,0)

			local Dragging = false
			
			local function UpdateSlider(Input)
				local SizeScale = math.clamp((Input.Position.X - SliderTrack.AbsolutePosition.X) / SliderTrack.AbsoluteSize.X, 0, 1)
				local NewValue = Round(SliderConfig.Min + ((SliderConfig.Max - SliderConfig.Min) * SizeScale), SliderConfig.Increment)
				
				SliderFrame.ValueLabel.Text = tostring(NewValue)
				TweenService:Create(SliderTrack.Fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(SizeScale, 0, 1, 0)}):Play()
				TweenService:Create(SliderDot, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(1, 0, 0.5, 0)}):Play()
				
				SliderConfig.Callback(NewValue)
				if SliderConfig.Flag then Library.Flags[SliderConfig.Flag] = {Value = NewValue, Type = "Slider", Save = SliderConfig.Save} end
			end

			AddConnection(SliderDot.InputBegan, function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					Dragging = true
					TweenService:Create(SliderDot.Dot, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 18, 0, 18)}):Play()
				end
			end)
			
			AddConnection(UserInputService.InputEnded, function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					Dragging = false
					TweenService:Create(SliderDot.Dot, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 14, 0, 14)}):Play()
				end
			end)

			AddConnection(UserInputService.InputChanged, function(Input)
				if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
					UpdateSlider(Input)
				end
			end)
			
			local DefaultScale = (SliderConfig.Default - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min)
			SliderTrack.Fill.Size = UDim2.new(DefaultScale, 0, 1, 0)
			SliderDot.Position = UDim2.new(1, 0, 0.5, 0)
			if SliderConfig.Flag then Library.Flags[SliderConfig.Flag] = {Value = SliderConfig.Default, Type = "Slider", Save = SliderConfig.Save} end
		end

		function ElementFunction:AddDropdown(DropdownConfig)
			DropdownConfig.Name = DropdownConfig.Name or "Dropdown"
			DropdownConfig.Options = DropdownConfig.Options or {}
			DropdownConfig.Default = DropdownConfig.Default or ""
			DropdownConfig.Callback = DropdownConfig.Callback or function() end
			DropdownConfig.Flag = DropdownConfig.Flag or nil
			DropdownConfig.Save = DropdownConfig.Save or false

			local DropdownOpen = false
			local CurrentOption = DropdownConfig.Default
			
			local DropdownFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Library.Themes[Library.SelectedTheme].Second, 0, 6), {
				Size = UDim2.new(1, 0, 0, 34),
				Parent = TabContainer,
				ClipsDescendants = true
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"),
				AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name, 14), {
					Size = UDim2.new(1, -140, 0, 34),
					Position = UDim2.new(0, 12, 0, 0),
					Font = Library.Font
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Label", CurrentOption, 13), {
					Size = UDim2.new(0, 100, 0, 34),
					Position = UDim2.new(1, -40, 0, 0),
					Font = Library.Font,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = Library.Themes[Library.SelectedTheme].TextDark,
					Name = "CurrentOption"
				}), "TextDark"),
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://6034818372"), {
					Size = UDim2.new(0, 14, 0, 14),
					Position = UDim2.new(1, -24, 0, 10),
					ImageColor3 = Library.Themes[Library.SelectedTheme].TextDark,
					Name = "Arrow"
				}), "TextDark")
			}), "Second")

			local OptionContainer = SetChildren(SetProps(MakeElement("List"), {
				Padding = UDim.new(0, 2)
			}), {
				Parent = nil 
			})
			
			local ContainerList = SetChildren(SetProps(MakeElement("Frame"), {
				Name = "List",
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 36),
				BackgroundTransparency = 1,
				Parent = DropdownFrame,
				ClipsDescendants = true
			}), {
				OptionContainer
			})

			local TriggerBtn = SetProps(MakeElement("Button"), {
				Size = UDim2.new(1, 0, 0, 34),
				Parent = DropdownFrame,
				ZIndex = 2
			})
			
			local function RefreshOptions()
				for _, child in pairs(ContainerList:GetChildren()) do
					if child:IsA("TextButton") then child:Destroy() end
				end
				
				for _, Option in pairs(DropdownConfig.Options) do
					local OptionBtn = AddThemeObject(SetChildren(SetProps(MakeElement("Button"), {
						Size = UDim2.new(1, -10, 0, 24),
						BackgroundColor3 = Library.Themes[Library.SelectedTheme].Main,
						Parent = ContainerList,
						Text = Option,
						Font = Library.Font,
						TextColor3 = Library.Themes[Library.SelectedTheme].TextDark,
						TextSize = 13,
						BackgroundTransparency = 0.5
					}), {
						MakeElement("Corner", 0, 4)
					}), "TextDark")
					
					OptionBtn.TextColor3 = Library.Themes[Library.SelectedTheme].TextDark
					
					if Option == CurrentOption then
						OptionBtn.TextColor3 = Library.Themes[Library.SelectedTheme].Accent
						OptionBtn.BackgroundTransparency = 0.2
					end
					
					AddConnection(OptionBtn.MouseButton1Click, function()
						CurrentOption = Option
						DropdownFrame.CurrentOption.Text = Option
						DropdownConfig.Callback(Option)
						RefreshOptions()
						
						DropdownOpen = false
						TweenService:Create(DropdownFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 0, 34)}):Play()
						TweenService:Create(DropdownFrame.Arrow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Rotation = 0}):Play()
						
						if DropdownConfig.Flag then Library.Flags[DropdownConfig.Flag] = {Value = Option, Type = "Dropdown", Save = DropdownConfig.Save} end
					end)
				end
				ContainerList.Size = UDim2.new(1, 0, 0, OptionContainer.AbsoluteContentSize.Y + 4)
			end

			AddConnection(TriggerBtn.MouseButton1Click, function()
				DropdownOpen = not DropdownOpen
				RefreshOptions()
				
				if DropdownOpen then
					local ContentSize = ContainerList.UIListLayout.AbsoluteContentSize.Y
					TweenService:Create(DropdownFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, ContentSize + 42)}):Play()
					TweenService:Create(DropdownFrame.Arrow, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Rotation = 180}):Play()
				else
					TweenService:Create(DropdownFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, 34)}):Play()
					TweenService:Create(DropdownFrame.Arrow, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Rotation = 0}):Play()
				end
			end)

			if DropdownConfig.Flag then Library.Flags[DropdownConfig.Flag] = {Value = DropdownConfig.Default, Type = "Dropdown", Save = DropdownConfig.Save} end
			RefreshOptions()
		end

		return ElementFunction
	end
	return TabFunction
end

return Library
