-- Igual que ContextActionService:BindAction, pero además guarda la función de cada acción para
-- que los botones de celular (UI/TouchButtons) puedan llamarla directo con Actions.Call.
-- (Antes usábamos ContextActionService:CallFunction, pero en el celular no hacía nada.)

local ContextActionService = game:GetService("ContextActionService")

type Handler = (string, Enum.UserInputState, InputObject) -> Enum.ContextActionResult?

local Actions = {}

local handlers: { [string]: Handler } = {}

function Actions.Bind(name: string, handler: Handler, createTouchButton: boolean, ...: any)
	handlers[name] = handler
	ContextActionService:BindAction(name, handler, createTouchButton, ...)
end

function Actions.BindAtPriority(name: string, handler: Handler, createTouchButton: boolean, priority: number, ...: any)
	handlers[name] = handler
	ContextActionService:BindActionAtPriority(name, handler, createTouchButton, priority, ...)
end

function Actions.Unbind(name: string)
	handlers[name] = nil
	ContextActionService:UnbindAction(name)
end

-- ¿La acción está puesta ahora mismo? (por ejemplo, el golpe con clic o la pócima del zombi)
function Actions.IsBound(name: string): boolean
	return handlers[name] ~= nil
end

-- Hace la acción como si se hubiera apretado su tecla
function Actions.Call(name: string, state: Enum.UserInputState, input: InputObject)
	local handler = handlers[name]
	if not handler then
		return
	end
	local ok, err = pcall(handler, name, state, input)
	if not ok then
		warn(`[Actions] {name}: {err}`)
	end
end

return Actions
