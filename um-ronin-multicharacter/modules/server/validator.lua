local registerConfig = require("config.register")

local SPECIAL_CHARS_PATTERN = "[<>\"`;\\%%{}%[%]%(%)%*%+%?%^%$|~!@#&=]"

function CountUtf8Chars(str)
    local _, count = str:gsub("[^\128-\193]", "")
    return count
end

function GetDateFormatPattern()
    local format = registerConfig.dob and registerConfig.dob.format or "DD-MM-YYYY"

    if format == "YYYY-MM-DD" then
        return "^(%d%d%d%d)%-(%d%d)%-(%d%d)$"
    end

    return "^(%d%d)%-(%d%d)%-(%d%d%d%d)$"
end

function IsValidName(name)
    if name:match("%d") then
        return false
    end

    if name:match(SPECIAL_CHARS_PATTERN) then
        return false
    end

    local stripped = name:gsub("%s", "")
    if stripped == "" then
        return false
    end

    return true
end

function ValidateField(fieldName, value, rules)
    if not rules.noString then
        if type(value) ~= "string" then
            return false, fieldName .. " must be a string"
        end
    end

    local trimmed = tostring(value):gsub("^%s*(.-)%s*$", "%1")
    local charCount = CountUtf8Chars(trimmed)

    if rules.min and charCount < rules.min then
        return false, fieldName .. " must be at least " .. rules.min .. " characters"
    end

    if rules.max and charCount > rules.max then
        return false, fieldName .. " must be at most " .. rules.max .. " characters"
    end

    if rules.regex then
        if not trimmed:match(rules.regex) then
            local errorMsg = rules and rules.errorMessage
            if not errorMsg then
                errorMsg = fieldName .. " is invalid"
            end
            return false, errorMsg
        end
    end

    if rules.validateName then
        if not IsValidName(trimmed) then
            local errorMsg = rules and rules.errorMessage
            if not errorMsg then
                errorMsg = fieldName .. " contains invalid characters"
            end
            return false, errorMsg
        end
    end

    if rules.nonempty then
        if #trimmed == 0 then
            return false, fieldName .. " is required"
        end
    end

    return true, trimmed
end

function ValidateRegistration(formData)
    local errors = {}

    local valid, result = ValidateField("Firstname", formData.firstname, {
        min = registerConfig.name and registerConfig.name.minLength or 2,
        max = registerConfig.name and registerConfig.name.maxLength or 100,
        validateName = true,
        nonempty = true
    })
    if not valid then
        errors.firstname = result
    end

    valid, result = ValidateField("Lastname", formData.lastname, {
        min = registerConfig.name and registerConfig.name.minLength or 2,
        max = registerConfig.name and registerConfig.name.maxLength or 100,
        validateName = true,
        nonempty = true
    })
    if not valid then
        errors.lastname = result
    end

    valid, result = ValidateField("Date of Birth", formData.birthdate, {
        regex = GetDateFormatPattern(),
        nonempty = true
    })
    if not valid then
        errors.birthdate = result
    end

    valid, result = ValidateField("Gender", formData.gender, {
        noString = true,
        regex = "^%d+$",
        nonempty = true
    })
    if not valid then
        errors.gender = result
    end

    if registerConfig.height then
        if formData and formData.height then
            valid, result = ValidateField("Height", formData.height, {
                noString = true,
                nonempty = true,
                regex = "^%d+$"
            })
            if not valid then
                errors.height = result
            end
        end
    end

    if registerConfig.backstory and registerConfig.backstory.enable then
        if formData and formData.backstory then
            valid, result = ValidateField("Backstory", formData.backstory, {
                nonempty = true,
                min = registerConfig.backstory.minLength or 10,
                max = registerConfig.backstory.maxLength or 300
            })
            if not valid then
                errors.backstory = result
            end
        end
    end

    valid, result = ValidateField("Nationality", formData.nationality, {
        max = 100,
        validateName = true,
        nonempty = true
    })
    if not valid then
        errors.nationality = result
    end

    if next(errors) then
        return false, errors
    end

    return true, "Validation successful"
end

function SetClearBackStory(backstory)
    if backstory and type(backstory) == "string" then
        return backstory:gsub(SPECIAL_CHARS_PATTERN, "")
    end

    return nil
end
