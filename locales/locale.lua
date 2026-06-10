LocalLang = {}

function LoadLocale(lang)
    local file = LoadResourceFile(GetCurrentResourceName(), 'locales/' .. lang .. '.json')
    if file then
        LocalLang = json.decode(file)
    else
        print('[Locale] Translation file not found for language: ' .. lang)
    end
end

function Locale(key)
    return LocalLang[key] or key
end


LoadLocale(Config.Locale)